!#define debug
!-------- to be costumized by user (usually done in the makefile)-------
!#define vector              compile for vector machine
!#define essl                use ESSL instead of LAPACK
!#define single_BLAS         use single prec. BLAS

!#define wNGXhalf            gamma only wavefunctions (X-red)
!#define wNGZhalf            gamma only wavefunctions (Z-red)

!#define NGXhalf             charge stored in REAL array (X-red)
!#define NGZhalf             charge stored in REAL array (Z-red)
!#define NOZTRMM             replace ZTRMM by ZGEMM
!#define REAL_to_DBLE        convert REAL() to DBLE()
!#define MPI                 compile for parallel machine with MPI
!------------- end of user part         --------------------------------
!
!   charge density: full grid mode
!
!
!   charge density complex
!
!
!   wavefunctions: full grid mode
!
!
!   wavefunctions complex
!
!
!   common definitions
!






      MODULE david
      USE prec
      CONTAINS
!************************ SUBROUTINE EDDDAV *****************************
! RCS:  $Id: davidson.F,v 1.5 2003/06/27 13:22:15 kresse Exp kresse $
!
! this subroutine performes a Davidson like optimsation of the
! wavefunctions i.e. it the expectation value
!     < phi | H |  phi >
! for NSIM bands in parallel
! 
! different preconditioners can be chosen using INFO%IALGO
!  INFO%IALGO   determine type of preconditioning and the algorithm
!    6    rms-minimization          +  TAP preconditioning
!    7    rms-minimization          +  no preconditioning
!    8    precond rms-minimization  +  TAP preconditioning
!    9    precond rms-minimization  +  Jacobi like preconditioning
!    (TAP Teter Alan Payne)
!  WEIMIN  treshhold for total energy minimisation
!    is the fermiweight of a band < WEIMIN,
!    minimisation will break after a maximum of two iterations
!  EBREAK  absolut break condition
!    intra-band minimisation is stopped if DE is < EBREAK
!
!***********************************************************************

      SUBROUTINE EDDAV(GRID,INFO,LATT_CUR,NONLR_S,NONL_S,W,WDES, NSIM, &
        LMDIM,CDIJ,CQIJ, RMS,DESUM,ICOUEV, SV, NBLOCK, IU6,IU0,  LDELAY, LSUBROTI)
      USE prec
      USE wave
      USE dfast
      USE base
      USE lattice
      USE mpimy
      USE mgrid
      USE nonl
      USE nonlr
      USE hamil
      USE constant
      USE wave_mpi
      USE scala
      IMPLICIT NONE

      TYPE (grid_3d)     GRID          ! descriptor for FFT grids
      TYPE (info_struct) INFO          ! INFO structure of VASP
      TYPE (latt)        LATT_CUR      !  
      TYPE (nonlr_struct) NONLR_S      ! descriptor for non local part of PP (real space)
      TYPE (nonl_struct) NONL_S        ! descriptor for non local part of PP (reciprocal space)
      TYPE (wavespin)    W             ! array for wavefunction
      TYPE (wavedes)     WDES          ! descriptor for wavefunction
      INTEGER NSIM                     ! simultaneously optimised bands
      INTEGER LMDIM                    ! dimension of arrays CQIJ and CDIJ
      COMPLEX(q) CDIJ(LMDIM,LMDIM,WDES%NIONS,WDES%NCDIJ), CQIJ(LMDIM,LMDIM,WDES%NIONS,WDES%NCDIJ)
      REAL (q)           RMS           ! on return: norm of residual vector summed over all bands
      REAL (q)           DESUM         ! on return: change of eigenvalues
      INTEGER            ICOUEV        ! number of intraband eigen value minimisations
      COMPLEX(q)   SV(GRID%MPLWV,WDES%NCDIJ) ! local potential
      INTEGER            NBLOCK        ! blocking size for some DGEMM operations
      INTEGER            IU6           ! stdout
      INTEGER            IU0           ! sterr
      LOGICAL LDELAY                   ! delay phase (not used) 
      LOGICAL LSUBROTI                 ! perform subspace rotation
! local work arrays
      TYPE (wavedes1)    WDES1         ! descriptor for (1._q,0._q) k-point
      COMPLEX(q),ALLOCATABLE,TARGET:: CF(:,:) ! stores the plane wave coefficients of optimisation subspace
      COMPLEX(q),ALLOCATABLE,TARGET::   CPROF(:,:)  ! stores the projected coefficients corresponding to CF
      COMPLEX(q),ALLOCATABLE,TARGET::   CPROW(:,:)  ! stores the projected coefficients of wave functions * Q
      COMPLEX(q),ALLOCATABLE,TARGET:: CH(:,:) ! stores H - epsilon S corresponding to CF
      COMPLEX(q), ALLOCATABLE      ::   CORTHO(:,:) ! stores <psi_i| S |psi_k>

      TYPE (wavefun1)    W1(NSIM)      ! wavefunction currently added to subspace
! redistributed plane wave coefficients
      COMPLEX(q), POINTER :: CW_RED(:,:),CH_RED(:,:),CF_RED(:,:)
      COMPLEX(q)   , POINTER :: CPROF_RED(:,:),CPROJ_RED(:,:),CPROW_RED(:,:)
      
      REAL(q),ALLOCATABLE:: PRECON(:,:)! preconditioning matrix for each
      COMPLEX(q),ALLOCATABLE:: CHAM(:,:),COVL(:,:),CEIG(:,:),COVL_(:,:)
      INTEGER :: NB(NSIM)              ! contains a list of bands currently optimized
      REAL(q) :: EVALUE_INI(NSIM)      ! eigenvalue of that band at the beginning
      REAL(q) :: EVALUE_GLBL(NSIM)     ! same as eigenvalue but global
      REAL(q) :: EVALUE_INI_GLBL(NSIM) ! same as eigenvalue but global
      REAL(q) :: DEIT                  ! relative break criterion for that band
      INTEGER :: IT(NSIM)              ! current iteration for this band
      LOGICAL :: LDO(NSIM)             ! band finished
      REAL(q) :: TRIAL(NSIM)           ! trial step for each band
      LOGICAL :: LSTOP                 ! optimisation finished
      LOGICAL :: LSUBROT               ! usually LSUBROTI
      LOGICAL :: DO_REDIS              ! redistribution of wavefunctions required
! nbands times nbands hamilton matrix and overlap matrix
      COMPLEX(q),ALLOCATABLE,TARGET::  CHAM_ALL(:,:),COVL_ALL(:,:)
! redistributed plane wave coefficients

! work arrays for ZHEEV (blocksize times number of bands)
      INTEGER, PARAMETER  :: LWORK=32
      COMPLEX(q),ALLOCATABLE    :: CWRK(:)
      REAL(q),ALLOCATABLE ::  R(:),RWORK(:)
      INTEGER :: NB_MAX
      INTEGER,PARAMETER :: IRWORK=7
      INTEGER,ALLOCATABLE :: IWORK(:), MINFO(:)
      REAL (q)   :: ABSTOL=1E-10_q, VL, VU 
      INTEGER    :: IL, IU, NB_CALC
! more local variables
      INTEGER :: NODE_ME, NODE_MEI, IONODE, NCPU, NSIM_LOCAL, NSIM_, NSIM_LOCAL_, &
           NSUBD, NITER, I, NRPLWV_RED, NPROD_RED, NBANDS, NB_TOT, ISP, NK, &
           NPL, NPRO, NPRO_O, NGVECTOR, NB_DONE, NP, N, ITER, NPP, M, MM,  IDUMP, &
           ISPINOR, NPL2, N1, N2, NPOS_RED, IFAIL, II, NITER_NOW
      REAL(q) :: SLOCAL, DE_ATT, EKIN, FAKT, X, X2, FNORM, FPRE_, DECEL, DEMAX
      COMPLEX(q) :: CPT


!=======================================================================
! initialise the required variables for MPI
!=======================================================================
      NODE_ME=1
      NODE_MEI=1
      IONODE =1
      NCPU=1
!=======================================================================
! number of bands treated simultaneously this must be a multiple of NCPU
!=======================================================================
      NSIM_LOCAL=NSIM/NCPU  ! number of bands optimised on this node
      IF (NSIM_LOCAL*NCPU /= NSIM) THEN
         WRITE(*,*) 'internal ERROR in EDDAV NSIM is not correct',NSIM
         STOP
      ENDIF

      LSUBROT=LSUBROTI
      IF (NSIM>=WDES%NB_TOT) THEN
         LSUBROT=.FALSE.
      ENDIF

      NITER =MAX(INFO%NDAV+1,2) ! maximum number of iterations
                                ! at least (1._q,0._q) optimisation step
      NSUBD =NITER*NSIM         ! maximum size of the subspace
      NB_MAX=NSUBD

      IF (LSUBROT) NB_MAX=MAX(NB_MAX,WDES%NB_TOT)
      ALLOCATE(PRECON(WDES%NRPLWV,NSIM_LOCAL), &
     &        CF(WDES%NRPLWV,NSIM_LOCAL*NITER),CPROF(WDES%NPROD,NSIM_LOCAL*NITER), &
     &        CH(WDES%NRPLWV,NSIM_LOCAL*NITER),CPROW(WDES%NPROD,NSIM_LOCAL), &
     &        CHAM(NSUBD,NSUBD),COVL(NSUBD,NSUBD),CEIG(NSUBD,NSUBD),COVL_(NSUBD,NSUBD), &
     &        CORTHO(WDES%NB_TOT,NSIM),R(NB_MAX),RWORK(NB_MAX*IRWORK),CWRK(LWORK*WDES%NB_TOT))
      DESUM =0
      RMS   =0
      ICOUEV=0

      ! average local potential
      SLOCAL=0
      DO I=1,GRID%RL%NP
        SLOCAL=SLOCAL+SV(I,1)
      ENDDO

      
      SLOCAL=SLOCAL/GRID%NPLWV

      DO I=1,NSIM_LOCAL
         CALL NEWWAV(W1(I) ,WDES,GRID%MPLWV*WDES%NRSPINORS,.TRUE.)
      ENDDO

      COVL=0
      CHAM=0
!-----------------------------------------------------------------------
! determine whether redistribution is required
!-----------------------------------------------------------------------
      IF (NCPU /= 1) THEN

        DO_REDIS=.TRUE.
        NRPLWV_RED=WDES%NRPLWV/NCPU
        NPROD_RED =WDES%NPROD /NCPU

      ELSE

        DO_REDIS=.FALSE.
        NRPLWV_RED=WDES%NRPLWV
        NPROD_RED =WDES%NPROD

      ENDIF
      NB_TOT=WDES%NB_TOT
      NBANDS=WDES%NBANDS

! allocate array for the subspace diagonalisation
      IF (LSUBROT) ALLOCATE(CHAM_ALL(NB_TOT,NB_TOT))
      IF (LSUBROT) ALLOCATE(IWORK(5*WDES%NB_TOT),MINFO(WDES%NB_TOT))

!=======================================================================
      spin:    DO ISP=1,WDES%ISPIN
      kpoints: DO NK=1,WDES%NKPTS
!=======================================================================
      CALL SETWDES(WDES,WDES1,NK); CALL SETWGRID(WDES1,GRID)

!   get pointers for redistributed wavefunctions
!   I can not guarantee that this works with all f90 compilers
!   please see comments in wave_mpi.F
      IF (DO_REDIS) THEN
        CALL SET_WPOINTER(CW_RED,   NRPLWV_RED, NB_TOT, W%CPTWFP(1,1,NK,ISP))
        CALL SET_WPOINTER(CF_RED,   NRPLWV_RED, NSIM*NITER, CF(1,1))
        CALL SET_WPOINTER(CH_RED,   NRPLWV_RED, NSIM*NITER, CH(1,1))
        CALL SET_GPOINTER(CPROJ_RED, NPROD_RED, NB_TOT, W%CPROJ(1,1,NK,ISP))
        CALL SET_GPOINTER(CPROF_RED, NPROD_RED, NSIM*NITER, CPROF(1,1))
        CALL SET_GPOINTER(CPROW_RED, NPROD_RED, NSIM, CPROW(1,1))
      ELSE
        CW_RED    => W%CPTWFP(:,:,NK,ISP)
        CH_RED    => CH(:,:)
        CF_RED    => CF(:,:)
        CPROJ_RED => W%CPROJ(:,:,NK,ISP)
        CPROF_RED => CPROF(:,:)
        CPROW_RED => CPROW(:,:)
      ENDIF

!   set number of coefficients after redistribution
      NPL = WDES1%NPL     ! number of plane waves/node after data redistribution
      NPRO= WDES1%NPRO    ! number of projected wavef. after data redistribution
      

      NPRO_O=NPRO         ! number of projected wavef. after data redistribution
                          ! used for the calculations of < psi | S | psi >
      IF (.NOT. INFO%LOVERL) NPRO_O=0


      NGVECTOR=WDES1%NGVECTOR


      DE_ATT=ABS(W%CELEN(NBANDS,NK,ISP)-W%CELEN(1,NK,ISP))

      IF (INFO%LREAL) THEN
        CALL PHASER(GRID,LATT_CUR,NONLR_S,NK,WDES,0.0_q,0.0_q,0.0_q)
      ELSE
        CALL PHASE(WDES,NONL_S,NK)
      ENDIF

      ! redistribute over plane wave coefficients
      IF (DO_REDIS) THEN
        CALL REDIS_PROJ(WDES1, NBANDS, W%CPROJ(1,1,NK,ISP))
        CALL REDIS_PW  (WDES1, NBANDS, W%CPTWFP   (1,1,NK,ISP))
      ENDIF


      IF (LSUBROT) CHAM_ALL=0

      NB=0          ! empty the list of bands, which are optimized currently
      NB_DONE=0     ! index the bands allready optimised
!=======================================================================
      bands: DO
!***********************************************************************
!
!  check the NB list, whether there is any empty slot
!  fill in a not yet optimized wavefunction into the slot
!  please mind, that optimisation is done in chuncks of NCPU bands
!  presently, we have more functionality in the sceduler 
!  then used
!
!***********************************************************************
      newband: DO NP=1,NSIM_LOCAL
      IF (NB(NP)==0 .AND.  NB_DONE < NBANDS ) THEN
        NB_DONE=NB_DONE+1
        N     =NB_DONE
        NB(NP)=NB_DONE

        ITER=1
        NPP=(ITER-1)*NSIM_LOCAL+NP
        ! fill current wavefunctions into work arrays CF at position NPP






! This is ok
        DO M=1,WDES%NRPLWV
           W1(NP)%CPTWFP(M)=W%CPTWFP(M,N,NK,ISP)
           CF(M,NPP)=W1(NP)%CPTWFP(M)
        ENDDO
        DO M=1,WDES%NPROD
           W1(NP)%CPROJ(M)=W%CPROJ(M,N,NK,ISP)
           CPROF(M,NPP)= W1(NP)%CPROJ(M)
        ENDDO

        ! now redistribute over bands
        IF (DO_REDIS) THEN
           CALL REDIS_PW(WDES1, 1, W1(NP)%CPTWFP(1))
           CALL REDIS_PROJ(WDES1, 1, W1(NP)%CPROJ(1))
        ENDIF
        
        IDUMP=0
        IF (IDUMP==2) WRITE(*,'(I3,1X)',ADVANCE='NO') N

        !===============================================================
        ! start with the exact evaluation of the eigenenergy
        !===============================================================
        IF (IDUMP==2) WRITE(*,'(F9.4)',ADVANCE='NO') REAL( W%CELEN(N,NK,ISP) ,KIND=q)

        DO ISPINOR=0,WDES%NRSPINORS-1
           CALL FFTWAV(NGVECTOR, WDES%NINDPW(1,NK),W1(NP)%CR(1+ISPINOR*GRID%MPLWV),W1(NP)%CPTWFP(1+ISPINOR*NGVECTOR),GRID)
        ENDDO
        CALL ECCP(WDES1,W1(NP),W1(NP),LMDIM,CDIJ(1,1,1,ISP),GRID,SV(1,ISP), W%CELEN(N,NK,ISP))

        ! propagate calculated eigenvalues to all 
        EVALUE_INI(NP)=W%CELEN(N,NK,ISP)

        EVALUE_GLBL((NP-1)*NCPU+1:NP*NCPU)=0
        EVALUE_GLBL((NP-1)*NCPU+NODE_MEI)= EVALUE_INI(NP)
        

        EVALUE_INI_GLBL((NP-1)*NCPU+1:NP*NCPU)= EVALUE_GLBL((NP-1)*NCPU+1:NP*NCPU)

        IF (IDUMP==2) WRITE(*,'(F9.4)',ADVANCE='NO') REAL( W%CELEN(N,NK,ISP) ,KIND=q)

        !===============================================================
        ! calculate the preconditioning matrix
        !===============================================================
        IF (INFO%IALGO==0 .OR. INFO%IALGO==8 .OR. INFO%IALGO==6 .OR. &
            (INFO%IALGO==9 .AND. LDELAY)) THEN
          EKIN=0

!DIR$ IVDEP
!OCL NOVREL
          DO ISPINOR=0,WDES%NRSPINORS-1
          DO M=1,NGVECTOR
             MM=M+ISPINOR*NGVECTOR
!-MM- changes to accommodate spin spinors
! original statements
!            IF (LDELAY .AND. WDES%DATAKE(M,NK)>INFO%ENINI) W1(NP)%CPTWFP(MM)=0
!            CPT=W1(NP)%CPTWFP(MM)
!            EKIN =EKIN+ REAL( CPT*CONJG(CPT) ,KIND=q) * WDES%DATAKE(M,NK)
             IF (LDELAY .AND. WDES%DATAKE(M,NK,ISPINOR+1)>INFO%ENINI) W1(NP)%CPTWFP(MM)=0
             CPT=W1(NP)%CPTWFP(MM)
             EKIN =EKIN+ REAL( CPT*CONJG(CPT) ,KIND=q) * WDES%DATAKE(M,NK,ISPINOR+1)
!-MM- end of alterations
          ENDDO
          ENDDO

          

          IF (EKIN<2.0_q) EKIN=2.0_q
          EKIN=EKIN*1.5_q
          IF (IDUMP==2)  WRITE(*,'(E9.2,"E")',ADVANCE='NO') EKIN

          FAKT=2._q/EKIN
          DO ISPINOR=0,WDES%NRSPINORS-1
          DO M=1,NGVECTOR
             MM=M+ISPINOR*NGVECTOR
!-MM- changes to accommodate spin spinors
! original statement
!            X=WDES%DATAKE(M,NK)/EKIN
             X=WDES%DATAKE(M,NK,ISPINOR+1)/EKIN
!-MM- end of alterations
             X2= 27+X*(18+X*(12+8*X))
             PRECON(MM,NP)=X2/(X2+16*X*X*X*X)*FAKT
          ENDDO
          ENDDO
        ELSE IF (INFO%IALGO==9) THEN
          DO ISPINOR=0,WDES%NRSPINORS-1
          DO M=1,NGVECTOR
            MM=M+ISPINOR*NGVECTOR
!            X=MAX(WDES%DATAKE(M,NK)+SLOCAL-EVALUE_INI(NP),0._q)
!            PRECON(MM,NP)= REAL( 1._q/(X+ CMPLX( 0 , DE_ATT ,KIND=q) ) ,KIND=q) !new
!-MM- changes to accommodate spin spinors
! original statement
!           X=WDES%DATAKE(M,NK)
            X=WDES%DATAKE(M,NK,ISPINOR+1)
!-MM- end of alterations
            IF (X<5) X=5
            PRECON(MM,NP)=1/X
          ENDDO
          ENDDO
        ELSE
          DO M=1,WDES1%NPL
             PRECON(M,NP)=1
          ENDDO
        ENDIF
        IT(NP)  =0
!=======================================================================
      ENDIF

      ENDDO newband
!=======================================================================
! if the NB list is now empty end the bands DO loop
!=======================================================================
200   CONTINUE
      LSTOP=.TRUE.
      LDO  =.FALSE.
      NSIM_LOCAL_=0
      DO NP=1,NSIM_LOCAL
         IF ( NB(NP) /= 0 ) THEN
            LSTOP  =.FALSE.
            LDO(NP)=.TRUE.     ! band not finished yet
            IT(NP) =IT(NP)+1   ! increase iteration count
            NSIM_LOCAL_=NSIM_LOCAL_+1
         ENDIF
      ENDDO

      ! right now all bands are consecutively ordered W1 or CF
      ! but it can happen that we treat less band in the last round
      NSIM_=NSIM_LOCAL_ * NCPU

      IF (LSTOP) EXIT bands
!***********************************************************************
!
! intra-band optimisation
! first calculate (H - epsilon)  psi 
!
!***********************************************************************
!gK here I can shift the eigenvalues to (0._q,0._q)
! this must not change the hamilton matrix 
!      EVALUE_INI=0
!      EVALUE_INI_GLBL=0

      ITER=IT(1)
      NPP=(ITER-1)*NSIM_LOCAL_+1   ! storage position in CF, CH
      !  store H | psi > in CH
      CALL HAMILTMU(WDES1,W1,NONLR_S,NONL_S,GRID,  INFO%LREAL,EVALUE_INI, &
     &     LMDIM,CDIJ(1,1,1,ISP),CQIJ(1,1,1,ISP), SV(1,ISP), CH(1,NPP),WDES%NRPLWV, NSIM_LOCAL_, LDO)

      DO NP=1,NSIM_LOCAL_
         N=NB(NP); ITER=IT(NP); IF (.NOT. LDO(NP)) CYCLE
         NPP=(ITER-1)*NSIM_LOCAL_+NP

         FNORM=0
         FPRE_ =0
         DO ISPINOR=0,WDES%NRSPINORS-1
         DO M=1,NGVECTOR
            MM=M+ISPINOR*NGVECTOR
            ! store result in CH and W1
            CH(MM,NPP)   =CH(MM,NPP)-EVALUE_INI(NP)*W1(NP)%CPTWFP(MM)
!-MM- changes to accommodate spin spirals
! original statements
!           W1(NP)%CPTWFP(MM)=CH(MM,NPP)
!           IF (LDELAY .AND. WDES%DATAKE(M,NK)>INFO%ENINI) CH(MM,NPP)=0
            IF (LDELAY .AND. WDES%DATAKE(M,NK,ISPINOR+1)>INFO%ENINI) CH(MM,NPP)=0
            W1(NP)%CPTWFP(MM)=CH(MM,NPP)
!-MM- end of alterations
            FNORM =FNORM+CH(MM,NPP)*CONJG(CH(MM,NPP))
            FPRE_ =FPRE_+CH(MM,NPP)*CONJG(CH(MM,NPP)) &
                 &              *PRECON(MM,NP)
         ENDDO
         ENDDO

         

         IF (IDUMP==2) WRITE(*,'(E9.2,"R")',ADVANCE='NO') SQRT(ABS(FNORM))
         IF (ITER==1) THEN
            RMS=RMS+WDES%RSPIN*WDES%WTKPT(NK)*W%FERWE(N,NK,ISP)* &
                 &      SQRT(ABS(FNORM))/NB_TOT
         ENDIF

      ! rearrange CH
         IF (DO_REDIS) THEN
            CALL REDIS_PW(WDES1, 1, CH(1,NPP))
         ENDIF

         IF (INFO%LOVERL .AND. WDES%NPROD>0 ) THEN
            WDES1%NBANDS=1    ! is used this only here not quite clean
            CALL OVERL(WDES1, INFO%LOVERL,LMDIM,CQIJ, W1(NP)%CPROJ(1),CPROW(1,NP))
            IF (DO_REDIS) THEN
               CALL REDIS_PROJ(WDES1, 1, CPROW(1,NP))
            ENDIF
         ENDIF

      ENDDO
!***********************************************************************
!
! update the elements of the Hamilton matrix and of the overlap matrix
! in the space spanned by the present wave functions
!
!***********************************************************************
      ! calulcate CQIJ * W1%CPROJ (required for overlap)
      ! get the index into the redistributed array
      ITER=IT(1)                  ! iter is right now the same for each band

      NPOS_RED=(ITER-1)*NSIM_+1   ! storage position in redistributed CF, CH

      CHAM(:,NPOS_RED:NPOS_RED+NSIM_-1)=0
      COVL(:,NPOS_RED:NPOS_RED+NSIM_-1)=0

      CALL ORTH1('U', &
        CF_RED(1,1),CH_RED(1,NPOS_RED),CPROF_RED(1,1), &
        CPROW_RED(1,1),NSUBD,NBLOCK, &
        NPOS_RED, NSIM_, NPL, 0 ,NRPLWV_RED,NPROD_RED,CHAM(1,1))

      CALL ORTH1('U', &
        CF_RED(1,1),CF_RED(1,NPOS_RED),CPROF_RED(1,1), &
        CPROW_RED(1,1),NSUBD,NBLOCK, &
        NPOS_RED, NSIM_, NPL, NPRO_O,NRPLWV_RED,NPROD_RED,COVL(1,1))


      
      

      ! add remaining elements to COVL
      DO M=1,NSIM_*(ITER-1)
      DO I=1,NSIM_
         COVL(NPOS_RED-1+I,M)=CONJG(COVL(M,NPOS_RED-1+I))
      ENDDO
      ENDDO
      ! correct CHAM by subtraction of epsilon COVL
      DO M=1,NSIM_*ITER
      DO I=1,NSIM_
         CHAM(M,NPOS_RED-1+I)=CHAM(M,NPOS_RED-1+I)+COVL(M,NPOS_RED-1+I)*EVALUE_INI_GLBL(I)
      ENDDO
      ENDDO

      DO N1=1,NSIM_*ITER
         IF (ABS(AIMAG(CHAM(N1,N1)))/MAX(1._q,ABS(REAL(CHAM(N1,N1))))>1E-6_q) THEN
            WRITE(*,*)                                                  &
               'WARNING: Sub-Space-Matrix is not hermitian in DAV ',N1, &
               AIMAG(CHAM(N1,N1))
         ENDIF
         CHAM(N1,N1)= REAL( CHAM(N1,N1) ,KIND=q)
      ENDDO

! solve eigenvalue-problem and calculate lowest eigenvector
! this eigenvector corresponds to a minimal residuum
! CHAM(n1,n2) U(n2,1) = E(1) S(n1,n2)  U(n2,1)

      IF (.FALSE.) THEN
         
         NPL2=MIN(10,ITER*NSIM_)
         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,1)N1,(REAL( CHAM(N1,N2) ,KIND=q) ,N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,3)N1,(AIMAG(CHAM(N1,N2)),N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,1)N1,(REAL( COVL(N1,N2) ,KIND=q) ,N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,3)N1,(AIMAG(COVL(N1,N2)),N2=1,NPL2)
         ENDDO
         WRITE(6,*)

 1       FORMAT(1I2,3X,20F9.5)
 3       FORMAT(1I2,3X,20E9.1)
         
      ENDIF

      CEIG (1:ITER*NSIM_,1:ITER*NSIM_) = CHAM(1:ITER*NSIM_,1:ITER*NSIM_)
      COVL_(1:ITER*NSIM_,1:ITER*NSIM_) = COVL(1:ITER*NSIM_,1:ITER*NSIM_)
      CALL ZHEGV &
     &  (1,'V','U',ITER*NSIM_,CEIG,NSUBD,COVL_(1,1),NSUBD,R, &
     &           CWRK(1),LWORK*NB_TOT,RWORK,IFAIL)
      

      IF (IFAIL/=0) THEN
         IF (IU6>=0) &
         WRITE(IU6,219) IFAIL,ITER,N
         IF (IU0>=0) &
         WRITE(IU0,219) IFAIL,ITER,N
!  try to save things somehow, goto next band
         STOP
      ENDIF
  219 FORMAT('Error EDDDAV: Call to ZHEGV failed. Returncode =',I4,I2,I2)

      IF (.FALSE.) THEN
      
         NPL2=MIN(10,ITER*NSIM_)

         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,1)N1,R(N1),(REAL( CEIG(N2,N1) ,KIND=q) ,N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         DO N1=1,NPL2
            WRITE(6,3)N1,R(N1),(AIMAG(CEIG(N2,N1)),N2=1,NPL2)
         ENDDO
         WRITE(6,*)
      
      ENDIF
!-----------------------------------------------------------------------
! update energies and calculate total energy change
!-----------------------------------------------------------------------
      II=0
      DEMAX=0
      DO NP=1,NSIM_LOCAL_
        N=NB(NP); ITER=IT(NP); IF (.NOT. LDO(NP)) CYCLE
        DO NPOS_RED=(N-1)*NCPU+1,N*NCPU
           II=II+1
           W%CELTOT(NPOS_RED,NK,ISP)=R(II) ! update CELTOT array
           DECEL =R(II)-EVALUE_GLBL(II)    ! change in eigenenergy
           
           ! if the change in the eigenenergy is very small 
           DEMAX=MAX(DEMAX, ABS(DECEL))

           IF (IDUMP==2)  WRITE(*,'(E10.2,2H |)',ADVANCE='NO') DECEL
           DESUM =DESUM +WDES%RSPIN*WDES%WTKPT(NK)*W%FERTOT(NPOS_RED,NK,ISP)*DECEL
           EVALUE_GLBL(II)         =R(II)  ! update 

        ENDDO
      ENDDO
!-----------------------------------------------------------------------
! possibly break the optimisation
! and new eigenenergy
!-----------------------------------------------------------------------
      LSTOP=.FALSE.

      ITER=IT(1)

      ! break if absolute change in eigenenergy is small
      ! -------------------------------------------------
      IF (ITER>1 .AND. DEMAX < INFO%EBREAK) LSTOP=.TRUE.
      ! relative break criterion 
      ! -------------------------------------------------
      IF (ITER==2) DEIT=DEMAX*INFO%DEPER
      IF (ITER>2 .AND. DEMAX < DEIT) LSTOP=.TRUE.

      ! set NITER_NOW according to the bands presently treated
      !IF (NB(NSIM_LOCAL) < WDES%NBANDS   /4) THEN
      !   NITER_NOW=MAX(3,NITER-2)
      !ELSE IF (NB(NSIM_LOCAL) < WDES%NBANDS /2) THEN
      !   NITER_NOW=MAX(3,NITER-1)
      !ELSE
      !   NITER_NOW=NITER
      !ENDIF
      !well the previous relative break criterion is more reliable
      NITER_NOW=NITER

      ! sufficient iterations done
      ! -------------------------------------------------
      IF (ITER >= NITER_NOW) LSTOP=.TRUE.
      IF (ITER >= NITER)     LSTOP=.TRUE.  ! certainly stop if storage requires this
!=======================================================================
! now store the optimised wave function back and return
!=======================================================================
      IF (LSTOP) THEN
      IF (IDUMP==2)  WRITE(*,*)

      NPOS_RED=(NB(1)-1)*NCPU

      CALL ZGEMM('N', 'N',  NPL , NSIM_, NSIM_*ITER, (1._q,0._q), &
     &               CF_RED(1,1),  NRPLWV_RED, CEIG(1,1), NSUBD,  &
     &               (0._q,0._q), CW_RED(1,NPOS_RED+1),  NRPLWV_RED)

      CALL ZGEMM('N', 'N', NPRO , NSIM_, NSIM_*ITER, (1._q,0._q), &
     &               CPROF_RED(1,1), NPROD_RED, CEIG(1,1), NSUBD,  &
     &               (0._q,0._q), CPROJ_RED(1,NPOS_RED+1), NPROD_RED)

!      DO II=1,NSIM_

!        CW_RED(1:NPL,NPOS_RED+II)     = 0
!        CPROJ_RED(1:NPRO,NPOS_RED+II) = 0
        
!        DO I=1,NSIM_*ITER
!           DO M=1,NPL
!              CW_RED   (M,NPOS_RED+II)=CW_RED   (M,NPOS_RED+II)+CEIG(I,II)*CF_RED(M,I)
!           ENDDO
!           DO M=1,NPRO
!              CPROJ_RED(M,NPOS_RED+II)=CPROJ_RED(M,NPOS_RED+II)+CEIG(I,II)*CPROF_RED(M,I)
!           ENDDO
!        ENDDO
!     ENDDO


     IF (LSUBROT) THEN
     ! store in the corresponding (H - epsilon S)  in CF_RED

      DO II=1,NSIM_
        CF_RED(1:NPL,II)      =0
        DO I=1,NSIM_*ITER
           DO M=1,NPL
              CF_RED   (M,II)=CF_RED   (M,II)+CEIG(I,II)*CH_RED(M,I)
           ENDDO
        ENDDO
      ENDDO
      ! calculate epsilon COVL
      NPOS_RED =(NB(1)-1)*NCPU+1

      CALL ORTH1('U', &
        CW_RED(1,1),CF_RED(1,1),CPROJ_RED(1,1), &
        CPROJ_RED(1,1),NB_TOT,NBLOCK, &
        NPOS_RED, NSIM_, NPL,0 ,NRPLWV_RED,NPROD_RED,CHAM_ALL(1,1))

      ! correct the small NSIM_ times NSIM_ block
      ! which is incorrect since we have calculate H - S epsilon psi
      ! and not H psi and since  our psi are not orthogonal to each other
      ! this block is however anyway diagonal with the elements R(I)
      CHAM_ALL(NPOS_RED:NPOS_RED+NSIM_-1,NPOS_RED:NPOS_RED+NSIM_-1)=0
      IF (NODE_ME==IONODE) THEN
         DO I=1,NSIM_
            CHAM_ALL(NPOS_RED-1+I,NPOS_RED-1+I)=R(I)
         ENDDO
      ENDIF
     ENDIF
     NB=0

     CYCLE bands
     ENDIF
!***********************************************************************
!
! precondition the vectors ( H - epsilon ) psi
! and orthogonalise to all other vectors
!
!***********************************************************************
     ICOUEV=ICOUEV+NSIM_
!-----------------------------------------------------------------------
! preconditioning of calculated residual vectors
!-----------------------------------------------------------------------
      DO NP=1,NSIM_LOCAL_
         N=NB(NP); ITER=IT(NP)+1; IF (.NOT. LDO(NP)) CYCLE
            
!DIR$ IVDEP
         DO M=1,WDES1%NPL
            W1(NP)%CPTWFP(M)=W1(NP)%CPTWFP(M)*PRECON(M,NP)
         ENDDO
      ENDDO
!-----------------------------------------------------------------------
! calculate the projection of these vectors and redistribute
!-----------------------------------------------------------------------
100   CONTINUE
      IF ( INFO%LREAL ) THEN
         DO NP=1,NSIM_LOCAL_
            N=NB(NP); ITER=IT(NP)+1; IF (.NOT. LDO(NP)) CYCLE
            
!DIR$ IVDEP
            DO M=1,WDES1%NPL
               W1(NP)%CPTWFP(M)=W1(NP)%CPTWFP(M)
            ENDDO

            DO ISPINOR=0,WDES1%NRSPINORS-1
               CALL FFTWAV(NGVECTOR,WDES%NINDPW(1,NK),W1(NP)%CR(1+ISPINOR*WDES1%MPLWV),W1(NP)%CPTWFP(1+ISPINOR*NGVECTOR),GRID)
            ENDDO
         ENDDO
         IF (NSIM_LOCAL_ >1 ) THEN
            CALL RPROMU(NONLR_S, WDES1, W1, NSIM_LOCAL_, LDO)
         ELSE
            DO NP=1,NSIM_LOCAL_
               IF (.NOT. LDO(NP)) CYCLE
               CALL RPRO1(NONLR_S, WDES1, W1(NP))
            ENDDO
         ENDIF
      ELSE
         DO NP=1,NSIM_LOCAL_
            N=NB(NP); ITER=IT(NP)+1; IF (.NOT. LDO(NP)) CYCLE
            
!DIR$ IVDEP
            DO M=1,WDES1%NPL
               W1(NP)%CPTWFP(M)=W1(NP)%CPTWFP(M)
            ENDDO
            CALL PROJ1(NONL_S,WDES1,W1(NP))
         ENDDO
      ENDIF

      DO NP=1,NSIM_LOCAL_
         N=NB(NP); ITER=IT(NP); IF (.NOT. LDO(NP)) CYCLE
         NPP=ITER*NSIM_LOCAL_+NP   ! storage position in CF, CH
!DIR$ IVDEP
         DO M=1,WDES1%NRPLWV
            CF(M,NPP)=W1(NP)%CPTWFP(M)
         ENDDO
!DIR$ IVDEP
         DO M=1,WDES%NPROD
            CPROF(M,NPP)= W1(NP)%CPROJ(M)
         ENDDO

         IF (DO_REDIS) THEN
            CALL REDIS_PW(WDES1, 1, CF(1,NPP))
            CALL REDIS_PROJ(WDES1, 1, CPROF(1,NPP))
         ENDIF

         IF (INFO%LOVERL .AND. WDES%NPROD>0 ) THEN
            WDES1%NBANDS=1    ! is used this only here not quite clean
            CALL OVERL(WDES1, INFO%LOVERL,LMDIM,CQIJ, W1(NP)%CPROJ(1),CPROW(1,NP))
            IF (DO_REDIS) THEN
               CALL REDIS_PROJ(WDES1, 1, CPROW(1,NP))
            ENDIF
         ENDIF
      ENDDO

!-----------------------------------------------------------------------
! overlap and orthogonalisation
!-----------------------------------------------------------------------
      NPOS_RED=ITER*NSIM_+1   ! storage position in CF_RED, CH_RED

      CORTHO=0

      CALL ORTH1('L', &
        CW_RED(1,1),CF_RED(1,NPOS_RED),CPROJ_RED(1,1), &
        CPROW_RED(1,1),NB_TOT,NBLOCK, &
        1, NSIM_, NPL, NPRO_O ,NRPLWV_RED,NPROD_RED,CORTHO(1,1))

      

      IF (.FALSE.) THEN
         
         NPL2=MIN(10,NB_TOT)
         WRITE(6,*)
         DO N1=1,NSIM_
            WRITE(6,1)N1,(REAL( CORTHO(N2,N1) ,KIND=q) ,N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         DO N1=1,NSIM_
            WRITE(6,3)N1,(AIMAG(CORTHO(N2,N1)),N2=1,NPL2)
         ENDDO
         WRITE(6,*)
         
      ENDIF

      CALL ZGEMM( 'N', 'N' ,  NPL , NSIM_ , NB_TOT , -(1._q,0._q) , &
                   CW_RED(1,1),  NRPLWV_RED , CORTHO(1,1) , NB_TOT , &
                   (1._q,0._q) , CF_RED(1,NPOS_RED) ,  NRPLWV_RED )

      IF (NPRO /= 0) &
      CALL ZGEMM( 'N', 'N' ,  NPRO , NSIM_ , NB_TOT  , -(1._q,0._q) , &
                   CPROJ_RED(1,1) ,  NPROD_RED , CORTHO(1,1) , NB_TOT , &
                   (1._q,0._q) , CPROF_RED(1,NPOS_RED) ,  NPROD_RED  )

!-----------------------------------------------------------------------
! now store the results back in W1, and perform an FFT to real space
!-----------------------------------------------------------------------
      DO NP=1,NSIM_LOCAL_
         
         N=NB(NP); ITER=IT(NP); IF (.NOT. LDO(NP)) CYCLE
         NPP=ITER*NSIM_LOCAL_+NP   ! storage position in CF, CH
         
!DIR$ IVDEP
         DO M=1,WDES1%NRPLWV
            W1(NP)%CPTWFP(M)=CF(M,NPP)
         ENDDO
!DIR$ IVDEP
         DO M=1,WDES%NPROD
             W1(NP)%CPROJ(M)=CPROF(M,NPP)
         ENDDO

         IF (DO_REDIS) THEN
           CALL REDIS_PW(WDES1, 1, W1(NP)%CPTWFP(1))
           CALL REDIS_PROJ(WDES1, 1, W1(NP)%CPROJ(1))
         ENDIF
         DO ISPINOR=0,WDES%NRSPINORS-1
           CALL FFTWAV(NGVECTOR, WDES%NINDPW(1,NK),W1(NP)%CR(1+ISPINOR*GRID%MPLWV),W1(NP)%CPTWFP(1+ISPINOR*NGVECTOR),GRID)
         ENDDO
      ENDDO
!=======================================================================
! move onto the next Band
!=======================================================================
      ENDDO bands
      
!***********************************************************************
!
! last step perform the sub space rotation
!
!***********************************************************************
 subr: IF(LSUBROT) THEN
      ! sum subspace matrix over all 
      


      DO N1=1,NB_TOT
        IF (ABS(AIMAG(CHAM_ALL(N1,N1)))>1E-2_q .AND. IU0>=0) THEN
          WRITE(IU0,*)'WARNING: Sub-Space-Matrix is not hermitian subr', &
     &              AIMAG(CHAM_ALL(N1,N1)),N1
        ENDIF
        CHAM_ALL(N1,N1)= REAL( CHAM_ALL(N1,N1) ,KIND=q)
      ENDDO

! here we support only scaLAPACK and LAPACK 

!
!  seriel codes
!
         ABSTOL=1E-10_q
         VL=0 ; VU=0 ; IL=0 ; IU=0
         ALLOCATE(COVL_ALL(NB_TOT,NB_TOT))
         CALL ZHEEVX( 'V', 'A', 'U', NB_TOT, CHAM_ALL(1,1) , NB_TOT, VL, VU, IL, IU, &
                            ABSTOL , NB_CALC , R, COVL_ALL(1,1), NB_TOT, CWRK, &
                            LWORK*NB_TOT, RWORK, IWORK, MINFO, IFAIL )         
         CHAM_ALL=COVL_ALL
         DEALLOCATE(COVL_ALL)
      ! T3D uses a global sum which does not guarantee to give the same results on all 
      ! the following line is required to make the code waterproof (we had problems)
      ! since we now use a propritary sum (see mpi.F) we should not require
      ! this broadcast anymore
      ! 

 1000 CONTINUE

      IF (IFAIL/=0) THEN
         WRITE(*,*) 'ERROR EDDIAG: Call to routine ZHEEV failed! '// &
     &              'Error code was ',IFAIL
         STOP
      ENDIF

      DO N=1,NB_TOT
        W%CELTOT(N,NK,ISP)=R(N)
      ENDDO

      CALL LINCOM('F',CW_RED(1,1),CPROJ_RED(1,1),CHAM_ALL(1,1), &
             NB_TOT,NB_TOT,NPL,NPRO,NRPLWV_RED,NPROD_RED,NB_TOT, &
             NBLOCK,CW_RED(1,1),CPROJ_RED(1,1))
      ! "lincom ok"
      
      ENDIF subr

      IF (DO_REDIS) THEN
        CALL REDIS_PROJ(WDES1, NBANDS, W%CPROJ(1,1,NK,ISP))
        CALL REDIS_PW  (WDES1, NBANDS, W%CPTWFP   (1,1,NK,ISP))
      ENDIF

      END DO kpoints
      ENDDO spin
!=======================================================================

      ! RMS was only calculate for the band treated locally (sum over all )
      

      DEALLOCATE(PRECON,CF,CPROF,CH,CPROW, CHAM, COVL, CEIG, COVL_, CORTHO, R, RWORK, CWRK)
      IF (LSUBROT) DEALLOCATE(CHAM_ALL)
      IF (LSUBROT) DEALLOCATE(IWORK,MINFO)
      DO I=1,NSIM_LOCAL
         CALL DELWAV(W1(I), .TRUE.)
      ENDDO

      RETURN
      END SUBROUTINE
      END MODULE


