!-------- to be costumized by user (usually done in the makefile)-------
!#define vector              compile for vector machine
!#define essl                use ESSL instead of LAPACK
!#define single_BLAS         use single prec. BLAS

!#define wNGXhalf            gamma only wavefunctions (X-red)
!#define wNGZhalf            gamma only wavefunctions (Z-red)

!#define 1             charge stored in REAL array (X-red)
!#define NGZhalf             charge stored in REAL array (Z-red)
!#define NOZTRMM             replace ZTRMM by ZGEMM
!#define REAL_to_DBLE        convert REAL() to DBLE()
!#define MPI                 compile for parallel machine with MPI
!------------- end of user part         --------------------------------
!
!   charge density: half grid mode X direction
!
!
!   charge density real
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





!****************** PROGRAM VASP  Version 4.6.20 (f90)*****************
! RCS:  $Id: main.F,v 1.18 2003/06/27 13:22:18 kresse Exp kresse $
! Vienna Ab initio total energy and Molecular-dynamics Program
!            written  by   Kresse Georg
!                     and  Juergen Furthmueller
! Georg Kresse                       email: Georg.Kresse@univie.ac.at
! Juergen Furthmueller               email: furth@ifto.physik.uni-jena.de
! Institut fuer Materialphysik         voice: +43-1-4277-51402
! Uni Wien, Sensengasse 8/12           fax:   +43-1-4277-9514 (or 9513)
! A-1090 Wien, AUSTRIA                 http://cms.mpi.univie.ac.at/kresse
!
! This program comes without any waranty.
! No part of this program must be distributed, modified, or supplied
! to any other person for any reason whatsoever
! without prior written permission of the Institut of Theoretical Physics
! TU Vienna, Austria.
!
! This program performs total energy calculations using
! a selfconsistency cylce (i.e. mixing + iterative matrix diagonal.)
! most of the algorithms implemented are described in
! G. Kresse and J. Furthmueller
!  Efficiency of ab--initio total energy calculations for
!   metals and semiconductors using a plane--wave basis set
!  Comput. Mat. Sci. 6,  15-50 (1996)
! G. Kresse and J. Furthmueller
!  Efficient iterative schemes for ab--initio total energy
!   calculations using a plane--wave basis set
!   Phys. Rev. B 54, 11169 (1996)
!
! The iterative matrix diagonalization is based
! a) on the conjugated gradient eigenvalue minimisation proposed by
!  D.M. Bylander, L. Kleinmann, S. Lee, Phys Rev. B 42, 1394 (1990)
! and is a variant of an algorithm proposed by
!  M.P. Teter, M.C. Payne and D.C. Allan, Phys. Rev. B 40,12255 (1989)
!  T.A. Arias, M.C. Payne, J.D. Joannopoulos, Phys Rev. B 45,1538(1992)
! b) or the residual vector minimization method (RMM-DIIS) proposed by
!  P. Pulay,  Chem. Phys. Lett. 73, 393 (1980).
!  D. M. Wood and A. Zunger, J. Phys. A, 1343 (1985)
! For the mixing a Broyden/Pulay like method is used (see for instance):
!  D. Johnson, Phys. Rev. B 38, 12807 (1988)
!
! The program works with normconserving PP, 
! generalised ultrasoft-PP (Vanderbilt-PP Vanderbilt Phys Rev B 40,  
! 12255 (1989)) and PAW (P.E. Bloechl, Phys. Rev. B{\bf 50}, 17953 (1994))
! datasets. Partial core corrections can be handled
! Spin and GGA are implemented
!
! The units used in the programs are electron-volts and angstroms.
! The unit cell is arbitrary, and arbitrary species of ions are handled.
! A full featured symmetry-code is included, and calculation of
! Monkhorst-Pack special-points is possible (tetrahedron method can be
! used as well).
!
! The integretion of the ionic movements is performed using a predictor-
! corrector (Nose) dynamics, a  conjugate gradient techniques,
! or a Broyden/Pulay like technique (RMM-DIIS)
!
! The original version was written by  M.C. Payne
! at Professor J. Joannopoulos research  group at the MIT
! (3000 lines, excluding FFT, July 1989)
! The program was completely rewritten and vasply extended by
! Kresse Georg (gK) and Juergen Furthmueller. Currently the
! code has about 60000 source lines
! Some of the additions made by gK:
!  nose-dynamic,  predictor-corrector scheme for
!  ionic movements, conjugate-gradient scheme,
!  sub-space alignment, non-local pseudopotentials in real and
!  reciprocal space, generalized Vanderbild pseudopotentials
!  general cellshapes, arbitrary species of ions, stresstensor
!  residual minimization,
!  all bands simultaneous update, US-PP, PAW method
! Juergen Furthmueller(jF) wrote the symmetry code, the special-kpoint
! generation code, Broyden/Pulay mixing (with support of gK),
! and implemented the first GGA version
!
!** The following parts have been taken from other programs
!   please contact the authors of these programs
!   before using them
! - Tetrahedron method (original author unknown, parts have been written
!                     by Peter Bloechl probably)
!
! please refer to the README file to learn about new features
! notes on singe-precision:
! USAGE NOT RECOMMENDED DUE TO FINITE DIFFERENCES IN SOME
! FORCES-ROUTINES
! (except for native 64-bit-REAL machines like the CRAYs ...)
!**********************************************************************

      PROGRAM VAMP
      USE prec

      USE charge
      USE pseudo
      USE lattice
      USE steep
      USE us
      USE paw
      USE pot
      USE force
      USE fileio
      USE nonl
      USE nonlr
      USE rmm_diis
      USE ini
      USE ebs
!      USE rot
      USE dfast
      USE choleski
      USE mwavpre
      USE mwavpre_noio
      USE msphpro
      USE broyden
      USE msymmetry
      USE subrot
      USE melf
      USE base
      USE mpimy
      USE mgrid
      USE mkpoints
      USE constant
      USE setexm
      USE poscar
      USE wave
      USE hamil
      USE main_mpi
      USE chain
      USE pardens
      USE finite_differences
      USE LDAPLUSU_MODULE
      USE cl
!-MM- Added to accomodate constrained moments etc
      USE Constrained_M_modular
      USE writer
!-MM- end of additions
      USE sym_prec
      USE elpol
      USE mdipol
      USE compat_gga
      USE vaspxml

      IMPLICIT COMPLEX(q) (C)
      IMPLICIT REAL(q) (A-B,D-H,O-Z)

!=======================================================================
!  a small set of parameters might be set here
!  but this is really rarely necessary :->
!=======================================================================
!-----hard limits for k-point generation package
!     NTETD  is the maximum number of tetrahedra which can be
!            stored when using the tetrahedron integration and
!     IKPTD  is the maximum number of k-mesh points in each
!            direction that can be stored in the 'connection'
!            tables for the k-points used for the symmetry
!            reduction of the tetrahedron tiling. Finally
      INTEGER, PARAMETER :: NKDIMD=10000,NTETD=90000,IKPTD=45
!----I/O-related things (adapt on installation or for special purposes)
!     IU6    overall output ('console protocol'/'OUTCAR' I/O-unit)
!     IU0    very important output ('standard [error] output I/O-unit')
!     IU5    input-parameters ('standard input'/INCAR I/O-unit)
!     ICMPLX size of complex items (in bytes/complex item)
!     MRECL  maximum record length for direct access files
!            (if no restictions set 0 or very large number)
      INTEGER,PARAMETER :: ICMPLX=16,MRECL=10000000

!=======================================================================
!  structures
!=======================================================================
      TYPE (potcar),ALLOCATABLE :: P(:)
      TYPE (wavedes)     WDES
      TYPE (nonlr_struct) NONLR_S
      TYPE (nonl_struct) NONL_S
      TYPE (wavespin)    W          ! wavefunction
      TYPE (wavefun)     W_F        ! wavefunction for all bands simultaneous
      TYPE (wavefun)     W_G        ! same as above
      TYPE (wavefun)     WUP
      TYPE (wavefun)     WDW
      TYPE (wavefun)     WTMP       ! temporary
      TYPE (wavespin)    WTMP_SPIN  ! temporary
      TYPE (latt)        LATT_CUR
      TYPE (latt)        LATT_INI
      TYPE (exctable)    EXCTAB
      TYPE (type_info)   T_INFO
      TYPE (dynamics)    DYN
      TYPE (info_struct) INFO
      TYPE (in_struct)   IO
      TYPE (mixing)      MIX
      TYPE (kpoints_struct) KPOINTS
      TYPE (symmetry)    SYMM
      TYPE (grid_3d)     GRID       ! grid for wavefunctions
      TYPE (grid_3d)     GRID_SOFT  ! grid for soft chargedensity
      TYPE (grid_3d)     GRIDC      ! grid for potentials/charge
      TYPE (grid_3d)     GRIDUS     ! very find grid temporarily used in us.F
      TYPE (grid_3d)     GRIDHF     ! grid used to present the potential
      TYPE (grid_3d)     GRIDB      ! Broyden grid
      TYPE (transit)     B_TO_C     ! index table between GRIDB and GRIDC
      TYPE (transit)     SOFT_TO_C  ! index table between GRID_SOFT and GRIDC
      TYPE (transit)     C_TO_US    ! index table between GRID_SOFT and GRIDC
      TYPE( prediction)  PRED
      TYPE (dipol)       DIP
      TYPE (smear_struct) SMEAR_LOOP
      TYPE (paco_struct) PACO
      TYPE (energy)      E,E2

      INTEGER :: NGX,NGY,NGZ,NGXC,NGYC,NGZC
      INTEGER :: NRPLWV,NBLK,LDIM,LMDIM,LDIM2,LMYDIM
      INTEGER :: IRMAX,IRDMAX,ISPIND
      INTEGER :: NPLWV,MPLWV,NPLWVC,MPLWVC,NTYPD,NIOND,NIONPD,NTYPPD
      INTEGER :: NBANDS
      INTEGER :: NEDOS
!R.S
      LOGICAL junk
      integer tiu6, tiu0, tiuvtot

!=======================================================================
!  begin array dimensions ...
!=======================================================================
!-----charge-density in real reciprocal space, partial core charge
      COMPLEX(q),ALLOCATABLE:: CHTOT(:,:)    ! charge-density in real / reciprocal space
      COMPLEX(q),ALLOCATABLE:: CHTOTL(:,:)   ! old charge-density
      REAL(q)     ,ALLOCATABLE:: DENCOR(:)     ! partial core
      COMPLEX(q),ALLOCATABLE:: CVTOT(:,:)    ! local potential
      COMPLEX(q),ALLOCATABLE:: CSTRF(:,:)    ! structure-factor
!-----METAGGA logical flag - obsolete: now in INFO
!      LOGICAL LMETAGGA
!-----non-local pseudopotential parameters
      REAL(q),ALLOCATABLE:: CDIJ(:,:,:,:) ! strength of PP
      REAL(q),ALLOCATABLE:: CQIJ(:,:,:,:) ! overlap of PP
      REAL(q),ALLOCATABLE:: CRHODE(:,:,:,:) ! augmentation occupancies
!-----elements required for mixing in PAW method
      REAL(q)   ,ALLOCATABLE::   RHOLM(:,:),RHOLM_LAST(:,:)
!-----charge-density and potential on small grid
      COMPLEX(q),ALLOCATABLE:: CHDEN(:,:)    ! soft part of charge density
      REAL(q)  ,ALLOCATABLE:: SV(:,:)       ! soft part of local potential
!-----description how to go from (1._q,0._q) grid to the second grid
!-----density of states
      REAL(q)   ,ALLOCATABLE::  DOS(:,:),DOSI(:,:)
      REAL(q)   ,ALLOCATABLE::  DDOS(:,:),DDOSI(:,:)
!-----local l-projected wavefunction characters
      REAL(q)   ,ALLOCATABLE::   PAR(:,:,:,:,:),DOSPAR(:,:,:,:)
!  all-band-simultaneous-update arrays
      COMPLEX(q)   ,ALLOCATABLE::   CHF(:,:,:),CHAM(:,:,:)
!  optics stuff
      COMPLEX(q)   ,ALLOCATABLE::   NABIJ(:,:)

!-----remaining mainly work arrays
      COMPLEX(q), ALLOCATABLE,TARGET :: CWORK1(:),CWORK2(:),CWORK(:,:)
      TYPE (wavefun1)    W1            ! current wavefunction
      TYPE (wavedes1)    WDES1         ! descriptor for (1._q,0._q) k-point

      COMPLEX(q), ALLOCATABLE  ::  CPROTM(:),CMAT(:,:)
!=======================================================================
!  a few fixed size (or small) arrays
!=======================================================================
!----- energy at each step
      REAL(q)      DESUM(500)
!-----Forces and stresses
      REAL(q)      TFORNL(3),TEIFOR(3),TEWIFO(3),THARFO(3),VTMP(3), &
     &          SIKEF(3,3),EISIF(3,3),DSIF(3,3),XCSIF(3,3), &
     &          PSCSIF(3,3),EWSIF(3,3),FNLSIF(3,3),AUGSIF(3,3), &
     &          TSIF(3,3),D2SIF(3,3),PARSIF(3,3)
!-----forces on ions
      REAL(q)   ,ALLOCATABLE::  EIFOR(:,:),EINL(:,:),EWIFOR(:,:), &
     &         HARFOR(:,:),TIFOR(:,:),PARFOR(:,:)
      REAL(q)  STM(5)
!-----Temporary data for tutorial messages ...
      INTEGER,PARAMETER :: NTUTOR=1000
      REAL(q)     RTUT(NTUTOR),RDUM
      INTEGER  ITUT(NTUTOR),IDUM
      COMPLEX(q)  CDUM  ; LOGICAL  LDUM
!=======================================================================
!  end array dimensions ...
!=======================================================================
      INTEGER NTYP_PP      ! number of types on POTCAR file

      INTEGER I,J,N,NT,K
!---- used for creation of param.inc
      REAL(q)    WFACT,PSRMX,PSDMX
      REAL(q)    XCUTOF,YCUTOF,ZCUTOF

!---- timing information
      INTEGER MINPGF,MAJPGF,ISWPS,IOOPS,IVCSW,IERR
      REAL(q)    UTIME,STIME,ETIME,RSIZM,AVSIZ

      INTEGER NORDER   !   order of smearing
!---- timing of individual calls
      REAL(q)    TC,TV,TC0,TV0

!---- a few logical and string variables
      LOGICAL    LTMP,LSTOP2
      LOGICAL    LPAW           ! paw is used 
      LOGICAL    LPARD          ! partial band decomposed charge density
      LOGICAL    LREALLOCATE    ! reallocation of proj operators required
      LOGICAL    L_NO_US        ! no ultrasoft PP
      LOGICAL    LADDGRID       ! additional support grid


      LOGICAL    LBERRY         ! calculate electronic polarisation
      CHARACTER (LEN=40)  SZ
      CHARACTER (LEN=1)   CHARAC
      CHARACTER (LEN=5)   IDENTIFY
!-----parameters for sphpro.f
      INTEGER :: LDIMP,LMDIMP,LTRUNC=3
!=======================================================================
! All COMMON blocks
!=======================================================================
      INTEGER IXMIN,IXMAX,IYMIN,IYMAX,IZMIN,IZMAX
      COMMON /WAVCUT/ IXMIN,IXMAX,IYMIN,IYMAX,IZMIN,IZMAX

      INTEGER  ISYMOP,NROT,IGRPOP,NROTK,INVMAP,NPCELL
      REAL(q)  GTRANS,AP
      REAL(q)  RHOTOT(4)
      INTEGER(8) IL,I1,I2_0,I3,I4
      CHARACTER (LEN=*),PARAMETER :: VASP='vasp.4.6.28 25Jul05 complex '

      COMMON /SYMM/   ISYMOP(3,3,48),NROT,IGRPOP(3,3,48),NROTK, &
     &                GTRANS(3,48),INVMAP(48),AP(3,3),NPCELL
!=======================================================================
!  initialise / set constants and parameters ...
!=======================================================================
      IO%LOPEN =.TRUE.  ! open all files with file names
      IO%IU0   = 6
      IO%IU6   = 8
      IO%IU5   = 5
!R.S
      tiu6 = IO%IU6
      tiu0 = IO%IU0

      IO%ICMPLX=ICMPLX
      IO%MRECL =MRECL
      PRED%ICMPLX=ICMPLX

      CALL TIMING(0,UTIME,STIME,ETIME,MINPGF,MAJPGF, &
     &            RSIZM,AVSIZ,ISWPS,IOOPS,IVCSW,IERR)
      IF (IERR/=0) ETIME=0._q
! switch off kill
!     CALL sigtrp()

      NPAR=1
      IUXML_SET=20
      CALL START_XML( IUXML_SET, "vasprun.xml" )
!-----------------------------------------------------------------------
!  open Files
!-----------------------------------------------------------------------
      IF (IO%IU0>=0) WRITE(TIU0,*) VASP
      IF (IO%IU6/=6 .AND. IO%IU6>0) &
      OPEN(UNIT=IO%IU6,FILE=DIR_APP(1:DIR_LEN)//'OUTCAR',STATUS='UNKNOWN')
      OPEN(UNIT=18,FILE=DIR_APP(1:DIR_LEN)//'CHGCAR',STATUS='UNKNOWN')

!R.S
      junk=.TRUE.
      INQUIRE(FILE=DIR_APP(1:DIR_LEN)//'WAVECAR',EXIST=junk)
      IO%LFOUND=junk

! first reopen with assumed (wrong) record length ICMPLX
      OPEN(UNIT=12,FILE=DIR_APP(1:DIR_LEN)//'WAVECAR',ACCESS='DIRECT', &
                   FORM='UNFORMATTED',STATUS='UNKNOWN',RECL=ICMPLX)
! the first record contains the record length, get it ...
      RDUM=0._q
      READ(12,REC=1,ERR=17421) RDUM,RISPIN ; IDUM=NINT(RDUM)
! in the worst case IDUM could contain completely useless data and useless is
! all <=0 or all >10000000 (since on output we use RECL=ICMPLX*MAX(NRPLWV,6)
! or RECL=(NB_TOT+2)*ICMPLX more than ten millions sounds not very realistic)
      IF ((IDUM<=0).OR.(IDUM>10000000)) IDUM=ICMPLX  ! -> error reading WAVECAR
      GOTO 17422
17421 CONTINUE
      IDUM=ICMPLX  ! -> error reading WAVECAR
17422 CONTINUE
      CLOSE(12)
! reopen with correct record length (clumsy all that, I know ...)
      OPEN(UNIT=12,FILE=DIR_APP(1:DIR_LEN)//'WAVECAR',ACCESS='DIRECT', &
                   FORM='UNFORMATTED',STATUS='UNKNOWN',RECL=IDUM)

      
      OPEN(UNIT=22,FILE=DIR_APP(1:DIR_LEN)//'EIGENVAL',STATUS='UNKNOWN')
      OPEN(UNIT=13,FILE=DIR_APP(1:DIR_LEN)//'CONTCAR',STATUS='UNKNOWN')
      OPEN(UNIT=16,FILE=DIR_APP(1:DIR_LEN)//'DOSCAR',STATUS='UNKNOWN')
      OPEN(UNIT=17,FILE=DIR_APP(1:DIR_LEN)//'OSZICAR',STATUS='UNKNOWN')
      OPEN(UNIT=60,FILE=DIR_APP(1:DIR_LEN)//'PCDAT',STATUS='UNKNOWN')
      OPEN(UNIT=61,FILE=DIR_APP(1:DIR_LEN)//'XDATCAR',STATUS='UNKNOWN')
      OPEN(UNIT=70,FILE=DIR_APP(1:DIR_LEN)//'CHG',STATUS='UNKNOWN')
      
      IF (IO%IU6>=0) WRITE(IO%IU6,*) VASP
      CALL XML_GENERATOR
      CALL PARSE_GENERATOR_XML(VASP//" serial")
      CALL MY_DATE_AND_TIME(IO%IU6)
      CALL XML_CLOSE_TAG

      CALL WRT_DISTR(IO%IU6)

! unit for extrapolation of wavefunction
      PRED%IUDIR =21
! unit for broyden mixing
      MIX%IUBROY=23
! unit for total potential
      IO%IUVTOT=62

 130  FORMAT (5X, //, &
     &'----------------------------------------------------', &
     &'----------------------------------------------------'//)

 140  FORMAT (5X, //, &
     &'----------------------------------------- Iteration ', &
     &I4,'(',I4,')  ---------------------------------------'//)
!-----------------------------------------------------------------------
! read header of POSCAR file to get NTYPD, NTYPDD, NIOND and NIONPD
!-----------------------------------------------------------------------
      CALL RD_POSCAR_HEAD(LATT_CUR, T_INFO, &
     &           NIOND,NIONPD, NTYPD,NTYPPD, IO%IU0, IO%IU6)

      ALLOCATE(T_INFO%ATOMOM(3*NIOND),T_INFO%RWIGS(NTYPPD),T_INFO%ROPT(NTYPD),T_INFO%POMASS(NTYPD))

      IF (IO%IU6>=0) THEN
         WRITE(TIU6,130)
         WRITE(TIU6,*)'INCAR:'
      ENDIF
!  first scan of POSCAR to get LDIM, LMDIM, LDIM2 ...
      LDIM =11
      LDIM2=(LDIM*(LDIM+1))/2
      LMDIM=32

      ALLOCATE(P(NTYPD))
      T_INFO%POMASS=0
      T_INFO%RWIGS=0

!-----------------------------------------------------------------------
! read pseudopotentials
!-----------------------------------------------------------------------
      CALL RD_PSEUDO(INFO,P, &
     &           NTYP_PP,NTYPD,LDIM,LDIM2,LMDIM, &
     &           T_INFO%POMASS,T_INFO%RWIGS, &
     &           IO%IU0,IO%IU6,-1,LPAW)

!-----------------------------------------------------------------------
! read INCAR
!-----------------------------------------------------------------------
      CALL XML_TAG("incar")

      CALL READER( &
          IO%IU5,IO%IU0,INFO%SZNAM1,INFO%ISTART,INFO%IALGO,MIX%IMIX,MIX%MAXMIX,MIX%MREMOVE, &
          MIX%AMIX,MIX%BMIX,MIX%AMIX_MAG,MIX%BMIX_MAG,MIX%AMIN, &
          MIX%WC,MIX%INIMIX,MIX%MIXPRE,IO%LFOUND,INFO%LDIAG,INFO%LREAL,IO%LREALD,IO%LPDENS, &
          DYN%IBRION,INFO%ICHARG,INFO%INIWAV,INFO%NELM,INFO%NELMIN,INFO%NELMDL,INFO%EDIFF,DYN%EDIFFG, &
          DYN%NSW,DYN%ISIF,PRED%IWAVPR,SYMM%ISYM,DYN%NBLOCK,DYN%KBLOCK,INFO%ENMAX,DYN%POTIM,DYN%TEBEG, &
          DYN%TEEND,DYN%NFREE, &
          PACO%NPACO,PACO%APACO,T_INFO%NTYP,NTYPD,DYN%SMASS,T_INFO%POMASS, &
          T_INFO%RWIGS,INFO%NELECT,INFO%NUP_DOWN,INFO%TIME,KPOINTS%EMIN,KPOINTS%EMAX,KPOINTS%ISMEAR,DYN%PSTRESS,INFO%NDAV, &
          KPOINTS%SIGMA,KPOINTS%LTET,INFO%WEIMIN,INFO%EBREAK,INFO%DEPER,IO%NWRITE,INFO%LCORR, &
          IO%IDIOT,T_INFO%NIONS,T_INFO%NTYPP,IO%LMUSIC,IO%LOPTICS,STM, &
          INFO%ISPIN,T_INFO%ATOMOM,NIOND,IO%LWAVE,IO%LCHARG,IO%LVTOT,INFO%SZPREC,INFO%SZGGA, &
          DIP%LCOR_DIP,DIP%IDIPCO,DIP%POSCEN,INFO%ENAUG,IO%LORBIT,IO%LELF,T_INFO%ROPT,INFO%ENINI, &
          NGX,NGY,NGZ,NGXC,NGYC,NGZC,NBANDS,NEDOS,NBLK,LATT_CUR, &
          LPLANE_WISE,LCOMPAT,LMAX_CALC,SET_LMAX_MIX_TO,WDES%NSIM,LFCI,LPARD,LPAW,LADDGRID,WDES%LCRITICAL_MEM, &
          WDES%LNONCOLLINEAR,WDES%LSORBIT,WDES%SAXIS,INFO%LMETAGGA, &
          WDES%LSPIRAL,WDES%LZEROZ,WDES%QSPIRAL, &
          INFO%LASPH,INFO%LSECVAR,INFO%IGGA2,INFO%SZGGA2)


       CALL LREAL_COMPAT_MODE(IO%IU5, IO%IU0, LCOMPAT)
       CALL GGA_COMPAT_MODE(IO%IU5, IO%IU0, LCOMPAT)

       IF (WDES%LNONCOLLINEAR) THEN
          INFO%ISPIN = 1
       ENDIF
! METAGGA not implemented for non collinear magnetism
       IF (WDES%LNONCOLLINEAR .AND. INFO%LMETAGGA) THEN
          WRITE(*,*) 'METAGGA for non collinear magnetism not supported.' 
          WRITE(*,*) 'exiting VASP; sorry for the inconveniences.'
          STOP
       ENDIF
!-MM- Spin spirals require LNONCOLLINEAR=.TRUE.
       IF (.NOT.WDES%LNONCOLLINEAR .AND. WDES%LSPIRAL) THEN
          WRITE(*,*) 'Spin spirals require LNONCOLLINEAR=.TRUE. '
          WRITE(*,*) 'exiting VASP; sorry dude!'
          STOP
       ENDIF
!-MM- end of addition

       IF (LCOMPAT) THEN
               CALL VTUTOR('W','VASP.4.4',RTUT,1, &
     &                  ITUT,1,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
               CALL VTUTOR('W','VASP.4.4',RTUT,1, &
     &                  ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
       ENDIF
! WRITE out an advice if some force dependent ionic algorithm and METAGGA
! or ASPH
       IF ((INFO%LMETAGGA .OR. INFO%LASPH) .AND. &
     &       (DYN%IBRION>0 .OR. (DYN%IBRION==0 .AND. DYN%SMASS/=-2))) THEN
          CALL VTUTOR('A','METAGGA and forces',RTUT,1, &
     &                  ITUT,1,CDUM,1,(/INFO%LASPH, INFO%LMETAGGA /),2, &
     &                  IO%IU0,IO%IDIOT)
       ENDIF
!-----------------------------------------------------------------------
! core level shift related items (parses INCAR)
!-----------------------------------------------------------------------
      CALL INIT_CL_SHIFT(IO%IU5,IO%IU0, T_INFO%NIONS, T_INFO%NTYP )

      CALL READER_ADD_ON(IO%IU5,IO%IU0,LBERRY,IGPAR,NPPSTR, &
            INFO%ICHARG,KPOINTS%ISMEAR,KPOINTS%SIGMA)

      ISPIND=INFO%ISPIN


      DYN%TEMP =DYN%TEBEG
      INFO%RSPIN=3-INFO%ISPIN

!-----------------------------------------------------------------------
! loop over different smearing parameters
!-----------------------------------------------------------------------
      SMEAR_LOOP%ISMCNT=0
      IF (KPOINTS%ISMEAR==-3) THEN
        IF(IO%IU6>=0)   WRITE(TIU6,7219)
 7219   FORMAT('   Loop over smearing-parameters in INCAR')
        CALL RDATAB(IO%LOPEN,'INCAR',IO%IU5,'SMEARINGS','=','#',';','F', &
     &            IDUM,SMEAR_LOOP%SMEARS(1),CDUM,LDUM,CHARAC,N,200,IERR)
        IF ((IERR/=0).OR.((IERR==0).AND. &
     &          ((N<2).OR.(N>200).OR.(MOD(N,2)/=0)))) THEN
           IF (IO%IU0>=0) &
           WRITE(TIU0,*)'Error reading item ''SMEARINGS'' from file INCAR.'
           STOP
        ENDIF
        SMEAR_LOOP%ISMCNT=N/2
        DYN%NSW   =SMEAR_LOOP%ISMCNT+1
        DYN%KBLOCK=DYN%NSW
        KPOINTS%LTET  =.TRUE.
        DYN%IBRION=-1
        KPOINTS%ISMEAR=-5
      ENDIF
!=======================================================================
!  now read in Pseudopotential
!=======================================================================
      LMDIM=0
      LDIM=0
      DO NT=1,NTYP_PP
        LMDIM=MAX(LMDIM,P(NT)%LMMAX)
        LDIM =MAX(LDIM ,P(NT)%LMAX)
      END DO
      CALL DEALLOC_PP(P,NTYP_PP)

      LDIM2=(LDIM*(LDIM+1))/2
      LMYDIM=9
! second scan with correct setting
      CALL RD_PSEUDO(INFO,P, &
     &           NTYP_PP,NTYPD,LDIM,LDIM2,LMDIM, &
     &           T_INFO%POMASS,T_INFO%RWIGS, &
     &           IO%IU0,IO%IU6,IO%NWRITE,LPAW)
      CALL CL_MODIFY_PP( NTYP_PP, P, ENAUG )
! now check everything
      CALL POST_PSEUDO(NTYPD,NTYP_PP,T_INFO%NTYP,T_INFO%NIONS,T_INFO%NITYP,P,INFO, &
     &        IO%LREALD,T_INFO%ROPT, IO%IDIOT,IO%IU6,IO%IU0,LMAX_CALC,L_NO_US)
      CALL LDIM_PSEUDO(IO%LORBIT, NTYPD, P, LDIMP, LMDIMP)
! setup PAW
      IF (.NOT.LPAW) IO%LOPTICS=.FALSE.

!-----------------------------------------------------------------------
! LDA+U initialisation (parses INCAR)
!-----------------------------------------------------------------------
      CALL LDAU_READER(T_INFO%NTYP,IO%IU5,IO%IU0)
      IF (USELDApU().OR.LCALC_ORBITAL_MOMENT()) &
     &   CALL INITIALIZE_LDAU(T_INFO%NIONS,T_INFO%NTYP,P,WDES%LNONCOLLINEAR,IO%IU0,IO%IDIOT)

      CALL SET_AUG(T_INFO%NTYP, P, IO%IU6, INFO%LEXCH, INFO%LEXCHG, LMAX_CALC, INFO%LMETAGGA, LCOMPAT)
!-----------------------------------------------------------------------
! optics initialisation (parses INCAR)
!-----------------------------------------------------------------------
      IF (IO%LOPTICS) CALL SET_NABIJ_AUG(P,T_INFO%NTYP)

!-----------------------------------------------------------------------
! exchange correlation table
!-----------------------------------------------------------------------
      IF (WDES%LNONCOLLINEAR .OR. INFO%ISPIN == 2) THEN
         CALL RD_EX(EXCTAB,2,INFO%LEXCH,IO%LEXCHF,IO%IU6,IO%IU0,IO%IDIOT)
      ELSE
         CALL RD_EX(EXCTAB,1,INFO%LEXCH,IO%LEXCHF,IO%IU6,IO%IU0,IO%IDIOT)
      ENDIF

!-----------------------------------------------------------------------
!  Read UNIT=15: POSCAR Startjob and Continuation-job
!-----------------------------------------------------------------------
      CALL RD_POSCAR(LATT_CUR, T_INFO, DYN, &
     &           NIOND,NIONPD, NTYPD,NTYPPD, &
     &           IO%IU0,IO%IU6)

!-----------------------------------------------------------------------
! constrained moment reader (INCAR reader)
!-----------------------------------------------------------------------
      CALL CONSTRAINED_M_READER(T_INFO%NIONS,IO%IU0,IO%IU5)
      CALL WRITER_READER(IO%IU0,IO%IU5)
!      CALL WANNIER_READER(IO%IU0,IO%IU5,IO%IU6,IO%IDIOT)
      CALL FIELD_READER(DIP,IO%IU0,IO%IU5)

!-----------------------------------------------------------------------
! init all chains (INCAR reader)
!-----------------------------------------------------------------------
      CALL chain_init( T_INFO, IO)

!-----------------------------------------------------------------------
!xml finish copying parameters from INCAR to xml file
! no INCAR reading from here 
      CALL XML_CLOSE_TAG("incar")
!-----------------------------------------------------------------------

      CALL COUNT_DEGREES_OF_FREEDOM( T_INFO, NDEGREES_OF_FREEDOM, &
          IO%IU6, IO%IU0, DYN%IBRION)

!-----for static calculations or relaxation jobs DYN%VEL is meaningless
      IF (DYN%INIT == -1) THEN
        CALL INITIO(T_INFO%NIONS,T_INFO%LSDYN,NDEGREES_OF_FREEDOM, &
               T_INFO%NTYP,T_INFO%ITYP,DYN%TEMP, &
               T_INFO%POMASS,DYN%POTIM, &
               DYN%POSION,DYN%VEL,T_INFO%LSFOR,LATT_CUR%A,LATT_CUR%B,DYN%INIT,IO%IU6)
        DYN%INIT=0
      ENDIF
      IF (DYN%IBRION/=0) THEN
          DYN%VEL=0._q
      ENDIF
      IF (IO%IU6>=0) THEN
         WRITE(TIU6,*)
         WRITE(TIU6,130)
      ENDIF

      IF ( T_INFO%LSDYN ) THEN
         CALL SET_SELECTED_VEL_ZERO(T_INFO, DYN%VEL,LATT_CUR)
      ELSE
         CALL SYMVEL_WARNING( T_INFO%NIONS, T_INFO%NTYP, T_INFO%ITYP, &
             T_INFO%POMASS, DYN%VEL, IO%IU6, IO%IU0 )
      ENDIF
      CALL NEAREST_NEIGHBOAR(IO%IU6, IO%IU0, T_INFO, LATT_CUR, P%RWIGS)
!-----------------------------------------------------------------------
!  initialize the symmetry stuff
!-----------------------------------------------------------------------
      ALLOCATE(SYMM%ROTMAP(NIOND,48,NIOND),SYMM%TAU(NIOND,3), &
     &         SYMM%TAUROT(NIOND,3),SYMM%WRKROT(3*(NIOND+2)), &
     &         SYMM%PTRANS(NIOND+2,3),SYMM%INDROT(NIOND+2))
      IF (INFO%ISPIN==2) THEN
         ALLOCATE(SYMM%MAGROT(48,NIOND))
      ELSE
         ALLOCATE(SYMM%MAGROT(1,1))
      ENDIF
      ! break symmetry parallel to IGPAR
      IF (LBERRY) THEN
         LATT_CUR%A(:,IGPAR)=LATT_CUR%A(:,IGPAR)*(1+TINY*10)
         CALL LATTIC(LATT_CUR)
      ENDIF
! Rotate the initial magnetic moments to counter the clockwise
! rotation brought on by the spin spiral
      IF (WDES%LSPIRAL) CALL COUNTER_SPIRAL(WDES%QSPIRAL,T_INFO%NIONS,T_INFO%POSION,T_INFO%ATOMOM)

      IF (SYMM%ISYM>0) THEN
! Finite temperature allows no symmetry by definition ...
         NCDIJ=INFO%ISPIN
         IF (WDES%LNONCOLLINEAR) NCDIJ=4
         CALL INISYM(LATT_CUR%A,DYN%POSION,DYN%VEL,T_INFO%LSFOR, &
                     T_INFO%LSDYN,T_INFO%NTYP,T_INFO%NITYP,NIOND, &
                     SYMM%PTRANS,SYMM%ROTMAP,SYMM%TAU,SYMM%TAUROT,SYMM%WRKROT, &
                     SYMM%INDROT,T_INFO%ATOMOM,WDES%SAXIS,SYMM%MAGROT,NCDIJ,IO%IU6)
      ELSE
! ... so take nosymm!
         CALL NOSYMM(LATT_CUR%A,T_INFO%NTYP,T_INFO%NITYP,NIOND,SYMM%PTRANS,SYMM%ROTMAP,SYMM%MAGROT,INFO%ISPIN,IO%IU6)
      END IF

!=======================================================================
!  Read UNIT=14: KPOINTS
!  number of k-points and k-points in reciprocal lattice
!=======================================================================
      IF(IO%IU6>=0)  WRITE(TIU6,*)
      NKDIM=NKDIMD

      IF (LBERRY) THEN
         CALL RD_KPOINTS_BERRY(KPOINTS,NPPSTR,IGPAR, &
        &   LATT_CUR, NKDIM,IKPTD,NTETD, &
        &   SYMM%ISYM>=0.AND..NOT.WDES%LSORBIT.AND..NOT.WDES%LSPIRAL, &
        &   IO%IU6,IO%IU0)
          IF (LBERRY) THEN
            LATT_CUR%A(:,IGPAR)=LATT_CUR%A(:,IGPAR)/(1+TINY*10)
            CALL LATTIC(LATT_CUR)
         ENDIF
      ELSE
         CALL RD_KPOINTS(KPOINTS,LATT_CUR, NKDIM,IKPTD,NTETD, &
           SYMM%ISYM>=0.AND..NOT.WDES%LSORBIT.AND..NOT.WDES%LSPIRAL, &
           IO%IU6,IO%IU0)
      ENDIF

      NKDIM=KPOINTS%NKPTS
!=======================================================================
!  at this point we have enough information to
!  create a param.inc file
!=======================================================================
      XCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(1)/AUTOA))
      YCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(2)/AUTOA))
      ZCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(3)/AUTOA))
!
!  setup NGX, NGY, NGZ if required
!
! high precission do not allow for wrap around
      IF (INFO%SZPREC(1:1)=='h' .OR. INFO%SZPREC(1:1)=='a') THEN
        WFACT=4
      ELSE
! medium-low precission allow for small wrap around
        WFACT=3
      ENDIF
      GRID%NGPTAR(1)=XCUTOF*WFACT+0.5_q
      GRID%NGPTAR(2)=YCUTOF*WFACT+0.5_q
      GRID%NGPTAR(3)=ZCUTOF*WFACT+0.5_q
      IF (NGX /= -1)   GRID%NGPTAR(1)=  NGX
      IF (NGY /= -1)   GRID%NGPTAR(2)=  NGY
      IF (NGZ /= -1)   GRID%NGPTAR(3)=  NGZ
      CALL FFTCHK(GRID%NGPTAR)
!
!  setup NGXC, NGYC, NGZC if required
!
      IF (INFO%LOVERL) THEN
        IF (INFO%ENAUG==0) INFO%ENAUG=INFO%ENMAX*1.5_q
        IF (INFO%SZPREC(1:1)=='h') THEN
          WFACT=16._q/3._q
        ELSE IF (INFO%SZPREC(1:1)=='l') THEN
          WFACT=3
        ELSE
          WFACT=4
        ENDIF
        XCUTOF =SQRT(INFO%ENAUG /RYTOEV)/(2*PI/(LATT_CUR%ANORM(1)/AUTOA))
        YCUTOF =SQRT(INFO%ENAUG /RYTOEV)/(2*PI/(LATT_CUR%ANORM(2)/AUTOA))
        ZCUTOF =SQRT(INFO%ENAUG /RYTOEV)/(2*PI/(LATT_CUR%ANORM(3)/AUTOA))
        GRIDC%NGPTAR(1)=XCUTOF*WFACT
        GRIDC%NGPTAR(2)=YCUTOF*WFACT
        GRIDC%NGPTAR(3)=ZCUTOF*WFACT
        ! prec Accurate and Medium double grids
        IF (INFO%SZPREC(1:1)=='a' .OR. INFO%SZPREC(1:1)=='n') THEN
           GRIDC%NGPTAR(1)=GRID%NGPTAR(1)*2
           GRIDC%NGPTAR(2)=GRID%NGPTAR(2)*2
           GRIDC%NGPTAR(3)=GRID%NGPTAR(3)*2
        ENDIF
        IF (NGXC /= -1)  GRIDC%NGPTAR(1)=NGXC
        IF (NGYC /= -1)  GRIDC%NGPTAR(2)=NGYC
        IF (NGZC /= -1)  GRIDC%NGPTAR(3)=NGZC
        CALL FFTCHK(GRIDC%NGPTAR)
      ELSE
        GRIDC%NGPTAR(1)= 1
        GRIDC%NGPTAR(2)= 1
        GRIDC%NGPTAR(3)= 1
      ENDIF

      GRIDC%NGPTAR(1)=MAX(GRIDC%NGPTAR(1),GRID%NGPTAR(1))
      GRIDC%NGPTAR(2)=MAX(GRIDC%NGPTAR(2),GRID%NGPTAR(2))
      GRIDC%NGPTAR(3)=MAX(GRIDC%NGPTAR(3),GRID%NGPTAR(3))
      GRIDUS%NGPTAR=GRIDC%NGPTAR
      IF (LADDGRID) GRIDUS%NGPTAR=GRIDC%NGPTAR*2

      NGX = GRID %NGPTAR(1); NGY = GRID %NGPTAR(2); NGZ = GRID %NGPTAR(3)
      NGXC= GRIDC%NGPTAR(1); NGYC= GRIDC%NGPTAR(2); NGZC= GRIDC%NGPTAR(3)
!
      IF (NBANDS == -1) THEN
         IF (WDES%LNONCOLLINEAR)  THEN
             NMAG=MAX(SUM(T_INFO%ATOMOM(1:T_INFO%NIONS*3-2:3)), &
                      SUM(T_INFO%ATOMOM(2:T_INFO%NIONS*3-1:3)), &
                      SUM(T_INFO%ATOMOM(3:T_INFO%NIONS*3:3)))
         ELSE IF (INFO%ISPIN > 1) THEN
             NMAG=SUM(T_INFO%ATOMOM(1:T_INFO%NIONS))
         ELSE
             NMAG=0
         ENDIF
         NMAG = (NMAG+1)/2
         NBANDS=MAX(NINT(INFO%NELECT+2)/2+MAX(T_INFO%NIONS/2,3),INT(0.6*INFO%NELECT))+NMAG
         IF (WDES%LNONCOLLINEAR) NBANDS = NBANDS*2
      ENDIF
!rS    IF (NBANDS == -1) NBANDS=0.6*INFO%NELECT + 4

      IF (INFO%EBREAK == -1) INFO%EBREAK=0.25_q*MIN(INFO%EDIFF,ABS(DYN%EDIFFG)/10)/NBANDS

      INFO%NBANDTOT=((NBANDS+NPAR-1)/NPAR)*NPAR


      IF ((.NOT. WDES%LNONCOLLINEAR) .and. INFO%NELECT>REAL(INFO%NBANDTOT*2,KIND=q)) THEN
         IF (IO%IU0>=0) &
            WRITE(TIU0,*)'ERROR: Number of bands NBANDS too small to hold', &
                           ' electrons',INFO%NELECT,INFO%NBANDTOT*2
         STOP
      ELSEIF((WDES%LNONCOLLINEAR) .and. ((INFO%NELECT*2)>REAL(INFO%NBANDTOT*2,KIND=q))) THEN
         IF (IO%IU0>=0) &
            WRITE(TIU0,*)'ERROR: Number of bands NBANDS too small to hold', &
                           ' electrons',INFO%NELECT,INFO%NBANDTOT
         STOP
      ENDIF

      NRPLWV=4*PI*SQRT(INFO%ENMAX /RYTOEV)**3/3* &
     &     LATT_CUR%OMEGA/AUTOA**3/(2*PI)**3*1.1_q+50

      IF (NBLK==-1) NBLK=MIN(256,MAX(32,(NRPLWV/320)*32))

      PSRMX=0
      PSDMX=0
      DO NT=1,T_INFO%NTYP
        PSRMX=MAX(PSRMX,P(NT)%PSRMAX)
        PSDMX=MAX(PSDMX,P(NT)%PSDMAX)
      ENDDO
      IF (INFO%LREAL) THEN
       IRMAX=4*PI*PSRMX**3/3/(LATT_CUR%OMEGA/ &
     &        (GRID%NGPTAR(1)*GRID%NGPTAR(2)*GRID%NGPTAR(3)))+50
      ELSE
       IRMAX=1
      ENDIF
      IRDMAX=1
      IF (INFO%LOVERL) THEN
       IRDMAX=4*PI*PSDMX**3/3/(LATT_CUR%OMEGA/ &
     &        (GRIDC%NGPTAR(1)*GRIDC%NGPTAR(2)*GRIDC%NGPTAR(3)))+200
      ENDIF
       IRDMAX=4*PI*PSDMX**3/3/(LATT_CUR%OMEGA/ &
     &        (GRIDUS%NGPTAR(1)*GRIDUS%NGPTAR(2)*GRIDUS%NGPTAR(3)))+200

      NPLWV =NGX *NGY *NGZ;
      MPLWV =NGX *NGY *NGZ
      NPLWVC=NGXC*NGYC*NGZC;
      MPLWVC=(NGXC/2+1)*NGYC*NGZC

!=======================================================================
!  set the basic quantities in WDES
!  and set the grids
!=======================================================================

      WDES%ENMAX =INFO%ENMAX

      WDES%NB_PAR=NPAR
      WDES%NB_TOT=INFO%NBANDTOT
      WDES%NBANDS=INFO%NBANDTOT/NPAR
      WDES%NB_LOW=1
      WDES%NKDIM =NKDIM
      WDES%NKPTS =KPOINTS%NKPTS
      WDES%ISPIN =INFO%ISPIN
      WDES%VKPT  =>KPOINTS%VKPT
      WDES%WTKPT =>KPOINTS%WTKPT
      WDES%COMM  =>COMM
      WDES%COMM_INB    =>COMM_INB
      WDES%COMM_INTER  =>COMM_INTER

      IF (WDES%LNONCOLLINEAR) then
         WDES%NRSPINORS = 2
         INFO%RSPIN = 1
      ELSE
         WDES%NRSPINORS = 1 
      ENDIF
      WDES%RSPIN = INFO%RSPIN

      CALL WDES_SET_NPRO(WDES,T_INFO,P)
!
! set up the descriptor for the initial wavefunctions
! (read from file)
      LATT_INI=LATT_CUR
! get header from WAVECAR file (LATT_INI is important)
! also set INFO%ISTART
      IF (INFO%ISTART > 0) THEN
        CALL INWAV_HEAD(WDES, LATT_INI, LATT_CUR, ENMAXI,INFO%ISTART, IO%IU0)
        IF (INFO%ISTART == 0 .AND. INFO%ICHARG == 0) INFO%ICHARG=2
      ENDIF
!=======================================================================
!  Write all important information
!=======================================================================
      IF (DYN%IBRION==5) THEN
         DYN%NSW=12*T_INFO%NIONS+1
         IF (DYN%NFREE /= 1 .AND. DYN%NFREE /= 2 .AND. DYN%NFREE /= 4)  DYN%NFREE =2
      ENDIF

      IF (IO%IU6>=0) THEN

      WRITE(TIU6,130)
      WRITE(TIU6,7205) KPOINTS%NKPTS,WDES%NB_TOT,NEDOS, &
     &              T_INFO%NIONS,LDIM,LMDIM, &
     &              NPLWV,IRMAX,IRDMAX, &
     &              NGX,NGY,NGZ, &
     &              NGXC,NGYC,NGZC,GRIDUS%NGPTAR,T_INFO%NITYP

      XAU= (NGX*PI/(LATT_CUR%ANORM(1)/AUTOA))
      YAU= (NGY*PI/(LATT_CUR%ANORM(2)/AUTOA))
      ZAU= (NGZ*PI/(LATT_CUR%ANORM(3)/AUTOA))
      WRITE(TIU6,7211) XAU,YAU,ZAU
      XAU= (NGXC*PI/(LATT_CUR%ANORM(1)/AUTOA))
      YAU= (NGYC*PI/(LATT_CUR%ANORM(2)/AUTOA))
      ZAU= (NGZC*PI/(LATT_CUR%ANORM(3)/AUTOA))
      WRITE(TIU6,7212) XAU,YAU,ZAU

      ENDIF

 7211 FORMAT(' NGX,Y,Z   is equivalent  to a cutoff of ', &
     &           F6.2,',',F6.2,',',F6.2,' a.u.')
 7212 FORMAT(' NGXF,Y,Z  is equivalent  to a cutoff of ', &
     &           F6.2,',',F6.2,',',F6.2,' a.u.'//)

      XCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(1)/AUTOA))
      YCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(2)/AUTOA))
      ZCUTOF =SQRT(INFO%ENMAX /RYTOEV)/(2*PI/(LATT_CUR%ANORM(3)/AUTOA))
! high precission do not allow for wrap around
      IF (INFO%SZPREC(1:1)=='h'.OR.INFO%SZPREC(1:1)=='a') THEN
        WFACT=4
      ELSE
! medium-low precission allow for small wrap around
        WFACT=3
      ENDIF
      ITUT(1)=XCUTOF*WFACT+0.5_q
      ITUT(2)=YCUTOF*WFACT+0.5_q
      ITUT(3)=ZCUTOF*WFACT+0.5_q
      IF (IO%IU6>=0) WRITE(TIU6,72111) ITUT(1),ITUT(2),ITUT(3)

72111 FORMAT(' I would recommend the setting:'/ &
     &       '   dimension x,y,z NGX = ',I5,' NGY =',I5,' NGZ =',I5)

      IF (NGX<ITUT(1) .OR. NGY<ITUT(2) .OR. NGZ<ITUT(3)) THEN
               CALL VTUTOR('W','FFT-GRID IS NOT SUFFICIENT',RTUT,1, &
     &                  ITUT,3,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
               CALL VTUTOR('W','FFT-GRID IS NOT SUFFICIENT',RTUT,1, &
     &                  ITUT,3,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ENDIF


      AOMEGA=LATT_CUR%OMEGA/T_INFO%NIONS
      QF=(3._q*PI*PI*INFO%NELECT/(LATT_CUR%OMEGA))**(1._q/3._q)*AUTOA

! chose the mass so that the typical Nose frequency is 40 timesteps
!-----just believe this (or look out  for all this factors in  STEP)
      IF (DYN%SMASS==0)  DYN%SMASS= &
         ((40._q*DYN%POTIM*1E-15_q/2._q/PI/LATT_CUR%ANORM(1))**2)* &
         2.E20_q*BOLKEV*EVTOJ/AMTOKG*NDEGREES_OF_FREEDOM*MAX(DYN%TEBEG,DYN%TEEND)
!      IF (DYN%SMASS<0)  DYN%SMASS= &
!         ((ABS(DYN%SMASS)*DYN%POTIM*1E-15_q/2._q/PI/LATT_CUR%ANORM(1))**2)* &
!         2.E20_q*BOLKEV*EVTOJ/AMTOKG*NDEGREES_OF_FREEDOM*MAX(DYN%TEBEG,DYN%TEEND)

      SQQ=  DYN%SMASS*(AMTOKG/EVTOJ)*(1E-10_q*LATT_CUR%ANORM(1))**2
      SQQAU=SQQ/RYTOEV
      IF (DYN%SMASS>0) THEN
        WOSZI= SQRT(2*BOLKEV*DYN%TEMP*NDEGREES_OF_FREEDOM/SQQ)
      ELSE
        WOSZI=1E-30_q
      ENDIF
!-----initial temperature
      CALL EKINC(EKIN,T_INFO%NIONS,T_INFO%NTYP,T_INFO%ITYP,T_INFO%POMASS,DYN%POTIM,LATT_CUR%A,DYN%VEL)
      TEIN = 2*EKIN/BOLKEV/NDEGREES_OF_FREEDOM
!-----be carefull about division by 0
      DYN%NBLOCK=MAX(1,DYN%NBLOCK)
      DYN%KBLOCK=MAX(1,DYN%KBLOCK)
      IF (DYN%NSW<DYN%KBLOCK*DYN%NBLOCK) DYN%KBLOCK=1
      IF (DYN%NSW<DYN%KBLOCK*DYN%NBLOCK) DYN%NBLOCK=MAX(DYN%NSW,1)

      DYN%NSW=INT(DYN%NSW/DYN%NBLOCK/DYN%KBLOCK)*DYN%NBLOCK*DYN%KBLOCK
      IF (IO%IU6>=0) THEN

      WRITE(TIU6,7210) INFO%SZNAM1,T_INFO%SZNAM2

      WRITE(TIU6,7206) IO%NWRITE,INFO%SZPREC,INFO%ISTART,INFO%ICHARG,WDES%ISPIN,WDES%LNONCOLLINEAR, &
     &      WDES%LSORBIT, INFO%INIWAV, &
     &      INFO%LASPH,INFO%LMETAGGA,  &
     &      INFO%ENMAX,INFO%ENMAX/RYTOEV,SQRT(INFO%ENMAX/RYTOEV), &
     &      XCUTOF,YCUTOF,ZCUTOF,INFO%ENINI, &
     &      INFO%ENAUG, &
     &      INFO%NELM,INFO%NELMIN,INFO%NELMDL,INFO%EDIFF,INFO%LREAL,LCOMPAT,LREAL_COMPAT,GGA_COMPAT, &
     &      LMAX_CALC,SET_LMAX_MIX_TO,LFCI, &
     &      T_INFO%ROPT
      WRITE(TIU6,7204) &
     &      DYN%EDIFFG,DYN%NSW,DYN%NBLOCK,DYN%KBLOCK, &
     &      DYN%IBRION,DYN%NFREE,DYN%ISIF,PRED%IWAVPR,SYMM%ISYM,INFO%LCORR

      TMP=0
      IF (DYN%POTIM>0) TMP=1/(WOSZI*(DYN%POTIM*1E-15_q)/2._q/PI)

      WRITE(TIU6,7207) &
     &      DYN%POTIM,TEIN,DYN%TEBEG,DYN%TEEND, &
     &      DYN%SMASS,WOSZI,TMP,SQQAU, &
     &      PACO%NPACO,PACO%APACO,DYN%PSTRESS

      WRITE(TIU6,7215) (T_INFO%POMASS(NI),NI=1,T_INFO%NTYP)
      RTUT(1:T_INFO%NTYP)=P(1:T_INFO%NTYP)%ZVALF ! work around IBM bug
      WRITE(TIU6,7216) (RTUT(NI),NI=1,T_INFO%NTYP)
      WRITE(TIU6,7203) (T_INFO%RWIGS(NI),NI=1,T_INFO%NTYP)

      WRITE(TIU6,7208) &
     &      INFO%NELECT,INFO%NUP_DOWN, &
     &      KPOINTS%EMIN,KPOINTS%EMAX,KPOINTS%ISMEAR,KPOINTS%SIGMA

      WRITE(TIU6,7209) &
     &      INFO%IALGO,INFO%LDIAG, &
     &      MIX%IMIX,MIX%AMIX,MIX%BMIX,MIX%AMIX_MAG,MIX%BMIX_MAG,MIX%AMIN, &
     &      MIX%WC,MIX%INIMIX,MIX%MIXPRE, &
     &      INFO%WEIMIN,INFO%EBREAK,INFO%DEPER,INFO%TIME, &
     &      AOMEGA,AOMEGA/(AUTOA)**3, &
     &      QF,QF**2*RYTOEV,QF**2
      WRITE(TIU6,72091) INFO%LSECVAR
      IF (INFO%LSECVAR) WRITE(TIU6,72092) INFO%SZGGA2
      WRITE(TIU6,*)
      WRITE(TIU6,7224) IO%LWAVE,IO%LCHARG,IO%LVTOT,IO%LELF,IO%LORBIT

      CALL WRITE_EFIELD(DIP,TIU6)

      ENDIF

 7210 FORMAT( &
     &       ' SYSTEM =  ',A40/ &
     &       ' POSCAR =  ',A40/)

 7205 FORMAT(//' Dimension of arrays:'/ &
     &       '   k-Points           NKPTS = ',I6, &
     &       '   number of bands    NBANDS= ',I6/ &
     &       '   number of dos      NEDOS = ',I6, &
     &       '   number of ions     NIONS = ',I6/ &
     &       '   non local maximal  LDIM  = ',I6, &
     &       '   non local SUM 2l+1 LMDIM = ',I6/ &
     &       '   total plane-waves  NPLWV = ',I6/ &
     &       '   max r-space proj   IRMAX = ',I6, &
     &       '   max aug-charges    IRDMAX= ',I6/ &
     &       '   dimension x,y,z NGX = ',I5,' NGY =',I5,' NGZ =',I5/ &
     &       '   dimension x,y,z NGXF= ',I5,' NGYF=',I5,' NGZF=',I5/ &
     &       '   support grid    NGXF= ',I5,' NGYF=',I5,' NGZF=',I5/ &
     &       '   ions per type =            ',10I4/)

 7206 FORMAT(' Startparameter for this run:'/ &
     &       '   NWRITE = ',I6,  '    write-flag & timer' / &
     &       '   PREC   = ',A6,  '    medium, high low'/ &
     &       '   ISTART = ',I6,  '    job   : 0-new  1-cont  2-samecut'/ &
     &       '   ICHARG = ',I6,  '    charge: 1-file 2-atom 10-const'/ &
     &       '   ISPIN  = ',I6,  '    spin polarized calculation?'/ &
     &       '   LNONCOLLINEAR = ',L6, ' non collinear calculations'/ &
     &       '   LSORBIT = ',L6, '    spin-orbit coupling'/ &
     &       '   INIWAV = ',I6,  '    electr: 0-lowe 1-rand  2-diag'/ &
     &       '   LASPH  = ',L6,  '    aspherical Exc in radial PAW'/ &
     &       '   METAGGA= ',L6,  '    non-selfconsistent MetaGGA calc.'// &
     &       ' Electronic Relaxation 1'/ &
     &       '   ENCUT  = ', &
     &              F6.1,' eV ',F6.2,' Ry  ',F6.2,' a.u. ', &
     &              3F6.2,'*2*pi/ulx,y,z'/ &
     &       '   ENINI  = ',F6.1,'     initial cutoff'/ &
     &       '   ENAUG  = ',F6.1,' eV  augmentation charge cutoff'/ &
     &       '   NELM   = ',I6,  ';   NELMIN=',I3,'; NELMDL=',I3, &
     &         '     # of ELM steps '    / &
     &       '   EDIFF  = ',E7.1,'   stopping-criterion for ELM'/ &
     &       '   LREAL  = ',L6,  '    real-space projection'     / &
     &       '   LCOMPAT= ',L6,  '    compatible to vasp.4.4'/&
     &       '   LREAL_COMPAT= ',L1,'    compatible to vasp.4.5.1-3'/&
     &       '   GGA_COMPAT  = ',L1,'    GGA compatible to vasp.4.4-vasp.4.6'/&
     &       '   LMAXPAW     = ',I4,' max onsite density'/&
     &       '   LMAXMIX     = ',I4,' max onsite mixed and CHGCAR'/&
     &       '   VOSKOWN= ',I6,  '    Vosko Wilk Nusair interpolation'/&
     &      ('   ROPT   = ',4F10.5))
 7204 FORMAT( &
     &       ' Ionic relaxation'/ &
     &       '   EDIFFG = ',E7.1,'   stopping-criterion for IOM'/ &
     &       '   NSW    = ',I6,  '    number of steps for IOM' / &
     &       '   NBLOCK = ',I6,  ';   KBLOCK = ',I6, &
     &         '    inner block; outer block '/ &
     &       '   IBRION = ',I6, &
     &         '    ionic relax: 0-MD 1-quasi-New 2-CG'/ &
     &       '   NFREE  = ',I6,  &
     &         '    steps in history (QN), initial steepest desc. (CG)'/ &
     &       '   ISIF   = ',I6,  '    stress and relaxation' / &
     &       '   IWAVPR = ',I6, &
     &         '    prediction:  0-non 1-charg 2-wave 3-comb' / &
     &       '   ISYM   = ',I6, &
     &         '    0-nonsym 1-usesym 2-fastsym' / &
     &       '   LCORR  = ',L6, &
     &         '    Harris-Foulkes like correction to forces' /)

 7207 FORMAT( &
     &       '   POTIM  = ',F6.2,'    time-step for ionic-motion'/ &
     &       '   TEIN   = ',F6.1,'    initial temperature'       / &
     &       '   TEBEG  = ',F6.1,';   TEEND  =',F6.1, &
     &               ' temperature during run'/ &
     &       '   SMASS  = ',F6.2,'    Nose mass-parameter (am)'/ &
     &       '   estimated Nose-frequenzy (Omega)   = ',E9.2, &
     &           ' period in steps =',F6.2,' mass=',E12.3,'a.u.'/ &
     &       '   NPACO  = ',I6,  ';   APACO  = ',F4.1, &
     &       '  distance and # of slots for P.C.'  / &
     &       '   PSTRESS= ',F6.1,' pullay stress'/)

!    &       '   damping for Cell-Motion     SIDAMP = ',F6.2/
!    &       '   mass for Cell-Motion        SIMASS = ',F6.2/

 7215 FORMAT('  Mass of Ions in am'/ &
     &       ('   POMASS = ',4F6.2))
 7216 FORMAT('  Ionic Valenz'/ &
     &       ('   ZVAL   = ',4F6.2))
 7203 FORMAT('  Atomic Wigner-Seitz radii'/ &
     &       ('   RWIGS  = ',4F6.2))

 7208 FORMAT( &
     &       '   NELECT = ',F12.4,  '    total number of electrons'/ &
     &       '   NUPDOWN= ',F12.4,  '    fix difference up-down'// &
     &       ' DOS related values:'/ &
     &       '   EMIN   = ',F6.2,';   EMAX   =',F6.2, &
     &       '  energy-range for DOS'/ &
     &       '   ISMEAR =',I6,';   SIGMA  = ',F6.2, &
     &       '  broadening in eV -4-tet -1-fermi 0-gaus'/)

 7209 FORMAT( &
     &       ' Electronic relaxation 2 (details)'/  &
     &       '   IALGO  = ',I6,  '    algorithm'            / &
     &       '   LDIAG  = ',L6,  '    sub-space diagonalisation' / &
     &       '   IMIX   = ',I6,  '    mixing-type and parameters'/ &
     &       '     AMIX     = ',F6.2,';   BMIX     =',F6.2/ &
     &       '     AMIX_MAG = ',F6.2,';   BMIX_MAG =',F6.2/ &
     &       '     AMIN     = ',F6.2/ &
     &       '     WC   = ',F6.0,';   INIMIX=',I4,';  MIXPRE=',I4// &
     &       ' Intra band minimization:'/ &
     &       '   WEIMIN = ',F6.4,'     energy-eigenvalue tresh-hold'/ &
     &       '   EBREAK = ',E9.2,'  absolut break condition' / &
     &       '   DEPER  = ',F6.2,'     relativ break condition  ' // &
     &       '   TIME   = ',F6.2,'     timestep for ELM'          // &
     &       '  volume/ion in A,a.u.               = ',F10.2,3X,F10.2/ &
     &       '  Fermi-wavevector in a.u.,eV,Ry     = ',3F10.6/)


 7224 FORMAT( &
     &       ' Write flags'/  &
     &       '   LWAVE  = ',L6,  '    write WAVECAR' / &
     &       '   LCHARG = ',L6,  '    write CHGCAR' / &
     &       '   LVTOT  = ',L6,  '    write LOCPOT, local potential' / &
     &       '   LELF   = ',L6,  '    write electronic localiz. function (ELF)'/&
     &       '   LORBIT = ',I6,  '    0 simple, 1 ext, 2 COOP (PROOUT)'//)

  72091 FORMAT( &
     &       ' Second variation'/ &
     &       '   LSECVAR=',L6,   '    do a second variation')
  72092 FORMAT( &
     &       '   GGA2   =    ',A2,'    type of second varitation GGA')

       IF (USELDApU()) CALL WRITE_LDApU(IO%IU6)
       CALL WRITE_CL_SHIFT(IO%IU6)
       CALL WRITE_BERRY_PARA(IO%IU6,LBERRY,IGPAR,NPPSTR)

       CALL XML_TAG("parameters")
       CALL XML_WRITER( &
          NPAR, &
          INFO%SZNAM1,INFO%ISTART,INFO%IALGO,MIX%IMIX,MIX%MAXMIX,MIX%MREMOVE, &
          MIX%AMIX,MIX%BMIX,MIX%AMIX_MAG,MIX%BMIX_MAG,MIX%AMIN, &
          MIX%WC,MIX%INIMIX,MIX%MIXPRE,IO%LFOUND,INFO%LDIAG,INFO%LREAL,IO%LREALD,IO%LPDENS, &
          DYN%IBRION,INFO%ICHARG,INFO%INIWAV,INFO%NELM,INFO%NELMIN,INFO%NELMDL,INFO%EDIFF,DYN%EDIFFG, &
          DYN%NSW,DYN%ISIF,PRED%IWAVPR,SYMM%ISYM,DYN%NBLOCK,DYN%KBLOCK,INFO%ENMAX,DYN%POTIM,DYN%TEBEG, &
          DYN%TEEND,DYN%NFREE, &
          PACO%NPACO,PACO%APACO,T_INFO%NTYP,NTYPD,DYN%SMASS,T_INFO%POMASS, &
          T_INFO%RWIGS,INFO%NELECT,INFO%NUP_DOWN,INFO%TIME,KPOINTS%EMIN,KPOINTS%EMAX,KPOINTS%ISMEAR,DYN%PSTRESS,INFO%NDAV, &
          KPOINTS%SIGMA,KPOINTS%LTET,INFO%WEIMIN,INFO%EBREAK,INFO%DEPER,IO%NWRITE,INFO%LCORR, &
          IO%IDIOT,T_INFO%NIONS,T_INFO%NTYPP,IO%LMUSIC,IO%LOPTICS,STM, &
          INFO%ISPIN,T_INFO%ATOMOM,NIOND,IO%LWAVE,IO%LCHARG,IO%LVTOT,INFO%SZPREC,INFO%SZGGA, &
          DIP%LCOR_DIP,DIP%IDIPCO,DIP%POSCEN,INFO%ENAUG,IO%LORBIT,IO%LELF,T_INFO%ROPT,INFO%ENINI, &
          NGX,NGY,NGZ,NGXC,NGYC,NGZC,NBANDS,NEDOS,NBLK,LATT_CUR, &
          LPLANE_WISE,LCOMPAT,LMAX_CALC,SET_LMAX_MIX_TO,WDES%NSIM,LFCI,LPARD,LPAW,LADDGRID,WDES%LCRITICAL_MEM, &
          WDES%LNONCOLLINEAR,WDES%LSORBIT,WDES%SAXIS,INFO%LMETAGGA, &
          WDES%LSPIRAL,WDES%LZEROZ,WDES%QSPIRAL, &
          INFO%LASPH,INFO%LSECVAR,INFO%IGGA2,INFO%SZGGA2)

       CALL  XML_WRITE_LREAL_COMPAT_MODE
       CALL  XML_WRITE_GGA_COMPAT_MODE
       CALL  XML_WRITE_BERRY(LBERRY, IGPAR, NPPSTR)
       CALL  XML_WRITE_CL_SHIFT
       CALL  XML_WRITE_LDAU
       CALL  XML_WRITE_CONSTRAINED_M(T_INFO%NIONS)

       CALL XML_CLOSE_TAG("parameters")
!=======================================================================
!  set some important flags and write out text information
!  DYN%IBRION        selects dynamic
!  INFO%LCORR =.TRUE. calculate Harris corrections to forces
!=======================================================================
!---- relaxation related information
      IF (DYN%IBRION==10) THEN
         INFO%NELMDL=ABS(INFO%NELM)
         INFO%LCORR=.TRUE.
         IF (DYN%POTIM <= 0.0001_q ) DYN%POTIM=1E-20_q
      ENDIF

      IF (IO%IU6>=0) THEN

      WRITE(TIU6,130)

      IF (DYN%IBRION == -1) THEN
        WRITE(TIU6,*)'Static calculation'
      ELSE IF (DYN%IBRION==0) THEN
        WRITE(TIU6,*)'molecular dynamics for ions'
        IF (DYN%SMASS>0) THEN
          WRITE(TIU6,*)'  using nose mass (canonical ensemble)'
        ELSE IF (DYN%SMASS==-3) THEN
          WRITE(TIU6,*)'  using a microcanonical ensemble'
        ELSE IF (DYN%SMASS==-1) THEN
          WRITE(TIU6,*)'  scaling velocities every NBLOCK steps'
        ELSE IF (DYN%SMASS==-2) THEN
          WRITE(TIU6,*)'  keeping initial velocities unchanged'
        ENDIF
      ELSE IF (DYN%IBRION==1) THEN
           WRITE(TIU6,*)'quasi-Newton-method for relaxation of ions'
      ELSE IF (DYN%IBRION==2) THEN
           WRITE(TIU6,*)'conjugate gradient relaxation of ions'
      ELSE IF (DYN%IBRION==3) THEN
              WRITE(TIU6,*)'quickmin algorithm: (dynamic with friction)'
      ELSE IF (DYN%IBRION==5) THEN
              WRITE(TIU6,*)'finite differences'
      ELSE IF (DYN%IBRION==10) THEN
           WRITE(TIU6,*)'relaxation of ions and charge simultaneously'
      ENDIF

      IF (DYN%IBRION/=-1 .AND. T_INFO%LSDYN) THEN
        WRITE(TIU6,*)'  using selective dynamics as specified on POSCAR'
        IF (.NOT.T_INFO%LDIRCO) THEN
          WRITE(TIU6,*)'  WARNING: If single coordinates had been '// &
     &                'selected the selection of coordinates'
          WRITE(TIU6,*)'           is made according to the '// &
     &                'corresponding   d i r e c t   coordinates!'
          WRITE(TIU6,*)'           Don''t support selection of '// &
     &                'single cartesian coordinates -- sorry ... !'
        ENDIF
      ENDIF
      ENDIF

      IF (INFO%ICHARG>=10) THEN
        INFO%LCHCON=.TRUE.
        IF(IO%IU6>=0)  WRITE(TIU6,*)'charge density remains constant during run'
        MIX%IMIX=0
      ELSE
        INFO%LCHCON=.FALSE.
        IF(IO%IU6>=0)  WRITE(TIU6,*)'charge density will be updated during run'
      ENDIF

      IF ((WDES%ISPIN==2).AND.INFO%LCHCON.AND.(DYN%IBRION/=-1)) THEN
         IF (IO%IU0>=0)  &
         WRITE(TIU0,*) &
          'Spin polarized Harris functional dynamics is a good joke ...'
         IF (IO%IU6>=0) &
         WRITE(TIU6,*) &
          'Spin polarized Harris functional dynamics is a good joke ...'
         STOP
      ENDIF
      IF (IO%IU6>=0) THEN
        IF (WDES%ISPIN==1 .AND. .NOT. WDES%LNONCOLLINEAR ) THEN
          WRITE(TIU6,*)'non-spin polarized calculation'
        ELSE IF ( WDES%LNONCOLLINEAR ) THEN
          WRITE(TIU6,*)'non collinear spin polarized calculation'
        ELSE
          WRITE(TIU6,*)'spin polarized calculation'
        ENDIF
      ENDIF

! paritial dos
      JOBPAR=1
!     IF (DYN%IBRION>=0) JOBPAR=0
      DO NT=1,T_INFO%NTYP
         IF (T_INFO%RWIGS(NT)<=0._q) JOBPAR=0
      ENDDO

!  INFO%LCDIAG  call EDDIAG after  eigenvalue optimization
!  INFO%LPDIAG  call EDDIAG before eigenvalue optimization
!  INFO%LDIAG   performe sub space rotation (when calling EDDIAG)
!  INFO%LORTHO  orthogonalization of wavefcuntions within optimization
!                     no Gram-Schmidt required
!  INFO%LRMM    use RMM-DIIS minimization
!  INFO%LDAVID  use blocked Davidson
!  INFO%LCHCON  charge constant during run
!  INFO%LCHCOS  charge constant during band minimisation
!  INFO%LONESW  all band simultaneous

      INFO%LCHCOS=.TRUE.
      INFO%LONESW=.FALSE.
      INFO%LDAVID=.FALSE.
      INFO%LRMM  =.FALSE.
      INFO%LORTHO=.TRUE.
      INFO%LPDIAG=.FALSE.
      INFO%LCDIAG=.FALSE.
      INFO%LPDIAG=.TRUE.

!  all bands CG
!  RMM-DIIS
      IF (INFO%IALGO>=60) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'RMM-DIIS sequential band-by-band and'
        IF(IO%IU6>=0)  WRITE(TIU6,*) ' variant of blocked Davidson during initial phase' 
        INFO%IALGO=INFO%IALGO-60
        INFO%LRMM   =.TRUE.
        INFO%LDAVID =.TRUE.
        INFO%LORTHO =.FALSE.
        INFO%LDIAG  =.TRUE.        ! subspace rotation is allways selected
      ELSE IF (INFO%IALGO>=50) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'Conjugate gradient for all bands'
        INFO%IALGO=MOD(INFO%IALGO,10)
        INFO%LCHCOS=INFO%LCHCON
        INFO%LONESW=.TRUE.
        WRITE(IO%IU6,*) ' This version does not support IALGO > 50'
        STOP
!  RMM-DIIS
      ELSE IF (INFO%IALGO>=40) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'RMM-DIIS sequential band-by-band'
        INFO%IALGO=INFO%IALGO-40
        INFO%LRMM  =.TRUE.
        INFO%LORTHO=.FALSE.
!  blocked Davidson (Liu)
      ELSE IF (INFO%IALGO>=30) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'Variant of blocked Davidson'
        INFO%IALGO=INFO%IALGO-30
        IF (INFO%LDIAG) THEN    ! if LDIAG is set
           IF(IO%IU6>=0)  WRITE(TIU6,*) 'Davidson routine will perform the subspace rotation'
           INFO%LCDIAG=.FALSE.  ! routine does the diagonalisation itself
           INFO%LPDIAG=.FALSE.  ! hence LPDIAG and LCDIAG are set to .FALSE.
        ENDIF
        INFO%LDAVID=.TRUE.
      ELSE IF (INFO%IALGO>=20) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'Conjugate gradient sequential band-by-band (Teter, Alan, Payne)'
        INFO%IALGO  =INFO%IALGO-20
        INFO%LORTHO=.FALSE.
         CALL VTUTOR('S','IALGO8',RTUT,1,ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ELSE IF (INFO%IALGO>=10) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*)'compatibility mode'
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'Conjugate gradient sequential band-by-band (Teter, Alan, Payne)'
        INFO%IALGO=INFO%IALGO-10
        INFO%LCDIAG=.TRUE.
        INFO%LPDIAG=.FALSE.
         CALL VTUTOR('S','IALGO8',RTUT,1,ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ELSE IF (INFO%IALGO>=5 .OR. INFO%IALGO==0) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'Conjugate gradient sequential band-by-band (Teter, Alan, Payne)'
         CALL VTUTOR('S','IALGO8',RTUT,1,ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ELSE IF (INFO%IALGO<0) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*) 'performance tests'
      ELSEIF (INFO%IALGO <2) THEN
        IF (IO%IU0>=0) &
        WRITE(TIU0,*)'algorithms no longer implemented'
        STOP
      ELSEIF (INFO%IALGO==3) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*)'only subspace rotation'
      ELSEIF (INFO%IALGO==4) THEN
        IF(IO%IU6>=0)  WRITE(TIU6,*)'none'
        INFO%LDIAG =.FALSE.
      ENDIF

      IF (INFO%LCHCOS) THEN
         SZ='   charged. constant during bandupdate'
      ELSE
         INFO%LCORR=.FALSE.
         MIX%IMIX=0
      ENDIF

      IF (IO%IU6>=0) THEN

      IF (.NOT. INFO%LRMM .AND. .NOT. INFO%LDAVID) THEN
        IF (INFO%IALGO==5) THEN
          WRITE(TIU6,*)'steepest descent',SZ
        ELSEIF (INFO%IALGO==6) THEN
          WRITE(TIU6,*)'conjugated gradient',SZ
        ELSEIF (INFO%IALGO==7) THEN
          WRITE(TIU6,*)'preconditioned steepest descent',SZ
        ELSEIF (INFO%IALGO==8) THEN
          WRITE(TIU6,*)'preconditioned conjugated gradient',SZ
        ELSEIF (INFO%IALGO==0) THEN
          WRITE(TIU6,*)'preconditioned conjugated gradient (Jacobi prec)',SZ
        ENDIF
        IF (.NOT.INFO%LONESW) THEN
          WRITE(TIU6,*)'   band-by band algorithm'
        ENDIF
      ENDIF

      IF (INFO%LDIAG) THEN
        WRITE(TIU6,*)'performe sub-space diagonalisation'
      ELSE
        WRITE(TIU6,*)'performe Loewdin sub-space diagonalisation'
        WRITE(TIU6,*)'   ordering is kept fixed'
      ENDIF

      IF (INFO%LPDIAG) THEN
        WRITE(TIU6,*)'   before iterative eigenvector-optimisation'
      ELSE
        WRITE(TIU6,*)'   after iterative eigenvector-optimisation'
      ENDIF

      IF (MIX%IMIX==1 .OR. MIX%IMIX==2 .OR. MIX%IMIX==3) THEN
        WRITE(TIU6,*)'Kerker-like  mixing scheme'
      ELSE IF (MIX%IMIX==4) THEN
       WRITE(TIU6,'(A,F10.1)')' modified Broyden-mixing scheme, WC = ',MIX%WC
       IF (MIX%INIMIX==1) THEN
         WRITE(TIU6,'(A,F8.4,A,F12.4)') &
     &     ' initial mixing is a Kerker type mixing with AMIX =',MIX%AMIX, &
     &     ' and BMIX =',MIX%BMIX
       ELSE IF (MIX%INIMIX==2) THEN
         WRITE(TIU6,*)'initial mixing equals unity matrix (no mixing!)'
       ELSE
         WRITE(TIU6,'(A,F8.4)') &
     &     ' initial mixing is a simple linear mixing with ALPHA =',MIX%AMIX
       ENDIF
       IF (MIX%MIXPRE==1) THEN
         WRITE(TIU6,*)'Hartree-type preconditioning will be used'
       ELSE IF (MIX%MIXPRE==2) THEN
         WRITE(TIU6,'(A,A,F12.4)') &
     &     ' (inverse) Kerker-type preconditioning will be used', &
     &     ' corresponding to BMIX =',MIX%BMIX
       ELSE
         WRITE(TIU6,*)'no preconditioning will be used'
       ENDIF
      ELSE
        WRITE(TIU6,*)'no mixing'
      ENDIF
      IF (WDES%NB_TOT*2==NINT(INFO%NELECT)) THEN
        WRITE(TIU6,*)'2*number of bands equal to number of electrons'
        IF (MIX%IMIX/=0 .AND..NOT.INFO%LCHCOS) THEN
          WRITE(TIU6,*) &
     &      'WARNING: mixing without additional bands will not converge'
        ELSE IF (MIX%IMIX/=0) THEN
          WRITE(TIU6,*) 'WARNING: mixing has no effect'
        ENDIF

      ELSE
        WRITE(TIU6,*)'using additional bands ',INT(WDES%NB_TOT-INFO%NELECT/2)
        IF (KPOINTS%SIGMA<=0) THEN
          WRITE(TIU6,*) &
     &  'WARNING: no broadening specified (might cause bad convergence)'
        ENDIF
      ENDIF

      IF (INFO%LREAL) THEN
        WRITE(TIU6,*)'real space projection scheme for non local part'
      ELSE
        WRITE(TIU6,*)'reciprocal scheme for non local part'
      ENDIF

      IF (INFO%LCORE) THEN
        WRITE(TIU6,*)'use partial core corrections'
      ENDIF

      IF (INFO%LCORR) THEN
        WRITE(TIU6,*)'calculate Harris-corrections to forces ', &
     &              '  (improved forces if not selfconsistent)'
      ELSE
        WRITE(TIU6,*)'no Harris-corrections to forces '
      ENDIF

      IF (INFO%LEXCHG/=0) THEN
        WRITE(TIU6,*)'use gradient corrections '
        IF (INFO%LCHCON) THEN
           IF (IO%IU0>=0) &
           WRITE(TIU0,*)'WARNING: stress and forces are not correct'
           WRITE(TIU6,*)'WARNING: stress and forces are not correct'
           WRITE(TIU6,*)' (second dervivative of E(xc) not defined)'
        ENDIF
      ENDIF

      IF (INFO%LOVERL) THEN
         WRITE(TIU6,*)'use of overlap-Matrix (Vanderbilt PP)'
      ENDIF
      IF (KPOINTS%ISMEAR==-1) THEN
        WRITE(TIU6,7213) KPOINTS%SIGMA
 7213 FORMAT(' Fermi-smearing in eV        SIGMA  = ',F6.2)

      ELSE IF (KPOINTS%ISMEAR==-2) THEN
        WRITE(TIU6,7214)
 7214 FORMAT(' partial occupancies read from INCAR (fixed during run)')
      ELSE IF (KPOINTS%ISMEAR==-4) THEN
        WRITE(TIU6,7222)
 7222 FORMAT(' Fermi weights with tetrahedron method witout', &
     &       ' Bloechl corrections')
      ELSE IF (KPOINTS%ISMEAR==-5) THEN
        WRITE(TIU6,7223)
 7223 FORMAT(' Fermi weights with tetrahedron method with', &
     &       ' Bloechl corrections')

      ELSE IF (KPOINTS%ISMEAR>0) THEN
        WRITE(TIU6,7217) KPOINTS%ISMEAR,KPOINTS%SIGMA
 7217 FORMAT(' Methfessel and Paxton  Order N=',I2, &
     &       ' SIGMA  = ',F6.2)
      ELSE
        WRITE(TIU6,7218) KPOINTS%SIGMA
 7218 FORMAT(' Gauss-broadening in eV      SIGMA  = ',F6.2)
      ENDIF

      WRITE(TIU6,130)
!=======================================================================
!  write out the lattice parameters
!=======================================================================
      WRITE(TIU6,7220) INFO%ENMAX,LATT_CUR%OMEGA, &
     &    ((LATT_CUR%A(I,J),I=1,3),(LATT_CUR%B(I,J),I=1,3),J=1,3), &
     &    (LATT_CUR%ANORM(I),I=1,3),(LATT_CUR%BNORM(I),I=1,3)

      WRITE(TIU6,*)

      IF (INFO%ISTART==1 .OR.INFO%ISTART==2) THEN

      WRITE(TIU6,*)'old parameters found on file WAVECAR:'
      WRITE(TIU6,7220) ENMAXI,LATT_INI%OMEGA, &
     &    ((LATT_INI%A(I,J),I=1,3),(LATT_INI%B(I,J),I=1,3),J=1,3)


      WRITE(TIU6,*)
 7220 FORMAT('  energy-cutoff  :  ',F10.2/ &
     &       '  volume of cell :  ',F10.2/ &
     &       '      direct lattice vectors',17X,'reciprocal lattice vectors'/ &
     &       3(2(3X,3F13.9)/) / &
     &       '  length of vectors'/ &
     &        (2(3X,3F13.9)/) /)

      ENDIF
!=======================================================================
!  write out k-points,weights,size & positions
!=======================================================================

 7104 FORMAT(' k-points in units of 2pi/SCALE and weight: ',A40)
 7105 FORMAT(' k-points in reciprocal lattice and weights: ',A40)
 7016 FORMAT(' position of ions in fractional coordinates (direct lattice) ')
 7017 FORMAT(' position of ions in cartesian coordinates  (Angst):')
 7009 FORMAT(1X,3F12.8,F12.3)
 7007 FORMAT(1X,3F12.8)

      WRITE(TIU6,7104) KPOINTS%SZNAMK

      DO NKP=1,KPOINTS%NKPTS
        VTMP(1)=WDES%VKPT(1,NKP)
        VTMP(2)=WDES%VKPT(2,NKP)
        VTMP(3)=WDES%VKPT(3,NKP)
        CALL DIRKAR(1,VTMP,LATT_CUR%B)
        WRITE(TIU6,7009) VTMP(1)*LATT_CUR%SCALE,VTMP(2)*LATT_CUR%SCALE, &
                  VTMP(3)*LATT_CUR%SCALE,KPOINTS%WTKPT(NKP)
      ENDDO

      WRITE(TIU6,*)
      WRITE(TIU6,7105) KPOINTS%SZNAMK
      DO NKP=1,KPOINTS%NKPTS
        WRITE(TIU6,7009) WDES%VKPT(1,NKP),WDES%VKPT(2,NKP),WDES%VKPT(3,NKP),KPOINTS%WTKPT(NKP)
      ENDDO
      WRITE(TIU6,*)

      WRITE(TIU6,7016)
      WRITE(TIU6,7007) ((DYN%POSION(I,J),I=1,3),J=1,T_INFO%NIONS)
      WRITE(TIU6,*)
      WRITE(TIU6,7017)

      DO J=1,T_INFO%NIONS
        VTMP(1)=DYN%POSION(1,J)
        VTMP(2)=DYN%POSION(2,J)
        VTMP(3)=DYN%POSION(3,J)
        CALL  DIRKAR(1,VTMP,LATT_CUR%A)
        WRITE(TIU6,7007) (VTMP(I),I=1,3)
      ENDDO
      WRITE(TIU6,*)

      WRITE(TIU6,130)
      ENDIF

      
!=======================================================================
!  write out initial header for PCDAT, XDATCAR
!=======================================================================
      CALL PCDAT_HEAD(60,T_INFO, LATT_CUR, DYN, PACO, INFO%SZNAM1)
      CALL XDAT_HEAD(61,T_INFO, LATT_CUR, DYN, INFO%SZNAM1)

!=======================================================================
!  write out initial header for DOS
!=======================================================================
      JOBPAR_=JOBPAR
      IF (IO%LORBIT>=10 ) JOBPAR_=1

      WRITE(16,'(4I4)') T_INFO%NIONP,T_INFO%NIONS,JOBPAR_,WDES%NCDIJ
      WRITE(16,'(5E15.7)')AOMEGA,((LATT_CUR%ANORM(I)*1E-10),I=1,3),DYN%POTIM*1E-15
      WRITE(16,*) DYN%TEMP
      WRITE(16,*) ' CAR '
      WRITE(16,*) INFO%SZNAM1

!=======================================================================
!  write out initial header for EIGENVALUES
!=======================================================================
      WRITE(22,'(4I5)') T_INFO%NIONS,T_INFO%NIONS,DYN%NBLOCK*DYN%KBLOCK,WDES%ISPIN
      WRITE(22,'(5E15.7)') &
     &         AOMEGA,((LATT_CUR%ANORM(I)*1E-10_q),I=1,3),DYN%POTIM*1E-15_q
      WRITE(22,*) DYN%TEMP
      WRITE(22,*) ' CAR '
      WRITE(22,*) INFO%SZNAM1
      WRITE(22,'(3I5)') NINT(INFO%NELECT),KPOINTS%NKPTS,WDES%NB_TOT
      

      IF (IO%IU0>=0) &
      WRITE(TIU0,*)'POSCAR, INCAR and KPOINTS ok, starting setup'
!=======================================================================
! initialize the required grid structures
!=======================================================================
      CALL INILGRD(NGX,NGY,NGZ,GRID)
      CALL INILGRD(NGX,NGY,NGZ,GRID_SOFT)
      CALL INILGRD(NGXC,NGYC,NGZC,GRIDC)
      CALL INILGRD(GRIDUS%NGPTAR(1),GRIDUS%NGPTAR(2),GRIDUS%NGPTAR(3),GRIDUS)
      CALL GEN_RC_GRID(GRIDUS)
      CALL GEN_RC_SUB_GRID(GRIDC,GRIDUS, C_TO_US, .TRUE.,.TRUE.)
      CALL GEN_RC_SUB_GRID(GRID_SOFT, GRIDC, SOFT_TO_C, .TRUE.,.TRUE.)
      CALL GEN_RC_GRID(GRIDUS)
!=======================================================================
!  allocate work arrays
!=======================================================================
!
! the indexing system for padding the spheres of plane waves at each
! k point into the box used for the fast fourier transforms is computed
! by GENSP as are the kinetic energies of the plane wave basis states
! ISTART=1 adjust padding scheme to LATT_CUR%B
      IF (INFO%ISTART==1) THEN
       CALL GEN_LAYOUT(GRID,WDES, LATT_CUR%B,LATT_CUR%B,IO%IU6,.TRUE.)
       CALL GEN_INDEX(GRID,WDES, LATT_CUR%B,LATT_CUR%B,IO%IU6,IO%IU0,.TRUE.)
! all other cases use LATT_INI for setup of GENSP
      ELSE
       ! 'call to genlay'
       CALL GEN_LAYOUT(GRID,WDES, LATT_CUR%B,LATT_INI%B,IO%IU6,.TRUE.)
       ! 'call to genind'
       CALL GEN_INDEX(GRID,WDES, LATT_CUR%B,LATT_INI%B,IO%IU6,IO%IU0,.TRUE.)
      ENDIF
!
! wavefunctions
!
      CALL ALLOCW(WDES,W,WUP,WDW)
      IF (INFO%LONESW) THEN
        CALL ALLOCW(WDES,WTMP_SPIN,W_F,WTMP)
        CALL ALLOCW(WDES,WTMP_SPIN,W_G,WTMP)
        ALLOCATE(CHAM(WDES%NB_TOT,WDES%NB_TOT,WDES%NKPTS), &
                 CHF (WDES%NB_TOT,WDES%NB_TOT,WDES%NKPTS))
      ELSE
        ALLOCATE(CHAM(1,1,1), &
                 CHF (1,1,1))
      ENDIF
!
! non local projection operators
!
      CALL NONL_ALLOC(NONL_S,T_INFO,P,WDES, INFO%LREAL)

!  set basic entities in NONLR_S
!-MM- Original call
!     CALL NONLR_SETUP(NONLR_S,T_INFO,P, INFO%LREAL)
! Changes for spin spirals
      CALL NONLR_SETUP(NONLR_S,T_INFO,P, INFO%LREAL, WDES%LSPIRAL)
!-MM- end of alteration
!  optimize grid for real space representation and calculate IRMAX, IRALLOC
      NONLR_S%IRMAX=0 ; NONLR_S%IRALLOC=0
      CALL REAL_OPTLAY(GRID,LATT_CUR,NONLR_S,LPLANE_WISE,LREALLOCATE, IO%IU6, IO%IU0)
! allign GRID_SOFT with GRID in real space
      CALL SET_RL_GRID(GRID_SOFT,GRID)
! allocate real space projectors
      CALL NONLR_ALLOC(NONLR_S)
!  init FFT
      CALL FFTINI(WDES%NINDPW(1,1),WDES%NGVECTOR(1),KPOINTS%NKPTS,WDES%NGDIM,GRID)
!
! allocate all other arrays
!
      ISP     =WDES%ISPIN
      NCDIJ   =WDES%NCDIJ
      NTYP    =T_INFO%NTYP
      NIOND   =T_INFO%NIOND
      NIOND_LOC=WDES%NIONS
      LMDIM   =P(1)%LMDIM

      MPLWVC=GRIDC%MPLWV
      NPLWVC=GRIDC%NPLWV

! charges, potentials and so on
      ALLOCATE(CHTOT(MPLWVC,NCDIJ),CHTOTL(MPLWVC,NCDIJ),DENCOR(NPLWVC), &
               CVTOT(MPLWVC,NCDIJ),CSTRF(MPLWVC,NTYP), &
! small grid quantities
               CHDEN(GRID_SOFT%MPLWV,NCDIJ),SV(GRID%MPLWV*2,NCDIJ), &
! non local things
               CDIJ(LMDIM,LMDIM,NIOND_LOC,NCDIJ), &
               CQIJ(LMDIM,LMDIM,NIOND_LOC,NCDIJ), &
               CRHODE(LMDIM,LMDIM,NIOND_LOC,NCDIJ), &
! forces (depend on NIOND)
               EIFOR(3,NIOND),EINL(3,NIOND),EWIFOR(3,NIOND), &
               HARFOR(3,NIOND),TIFOR(3,NIOND),PARFOR(3,NIOND), &
! dos
               DOS(NEDOS,NCDIJ),DOSI(NEDOS,NCDIJ), &
               DDOS(NEDOS,NCDIJ),DDOSI(NEDOS,NCDIJ), &
               PAR(1,1,1,1,1),DOSPAR(1,1,1,1), &
! paco
               PACO%SIPACO(0:PACO%NPACO))
      ! 'allocation done'
!
! fftw requires a few calls to make a masterplan
!
      ALLOCATE(CWORK1(GRID%MPLWV+1024))
      

      IF (IO%IU0>=0) WRITE(TIU0,*)'FFT: planning ...',MIN(MAX(DYN%NSW,1),MIN(16,(WDES%NBANDS+16)/16))
!      DO N=1,MIN(MAX(DYN%NSW,1),MIN(16,WDES%NBANDS))
      DO N=1,MIN(MAX(DYN%NSW,1),MIN(16,(WDES%NBANDS+16)/16))
        CALL INIDAT(GRID%RC%NP,CWORK1)
        CALL FFTMAKEPLAN(CWORK1(N),GRID)
      ENDDO
      DEALLOCATE(CWORK1)

      MPLMAX=MAX(GRIDC%MPLWV,GRID_SOFT%MPLWV,GRID%MPLWV)
      MIX%NEIG=0
! calculate required numbers elements which must be mixed in PAW
      ! set table for Clebsch-Gordan coefficients, maximum L is 3 (f states)
      LMAX_TABLE=5 ;  CALL YLM3ST_(LMAX_TABLE)
      N_MIX_PAW=0

      CALL SET_ATOM_POT(P , T_INFO, INFO%LOVERL, &
         LMDIM, INFO%LEXCH, INFO%LEXCHG  )
      CALL SET_RHO_PAW_ELEMENTS(WDES, P , T_INFO, INFO%LOVERL, N_MIX_PAW )

      ALLOCATE( RHOLM(N_MIX_PAW,WDES%NCDIJ), RHOLM_LAST(N_MIX_PAW,WDES%NCDIJ))
!=======================================================================
! now read in wavefunctions
!=======================================================================
      W%CELTOT=0

      IF (IO%IU0>=0) WRITE(TIU0,*)'reading WAVECAR'
!#ifdef MPI
      IF (INFO%ISTART>0) CALL INWAV_FAST(WDES, W, GRID, LATT_CUR, LATT_INI, ISTART, IO%IU0)
!#else
!      IF (INFO%ISTART>0) CALL INWAV(WDES,W,GRID,IO,LATT_INI, ISTART)
!#endif

      IF (INFO%ISTART/=2) LATT_INI=LATT_CUR
      NSUM=0
      NPLMAX=0
      DO K=1,KPOINTS%NKPTS
       NPLMAX=MAX(NPLMAX,WDES%NPLWKP_TOT(K))
       NSUM=NSUM+WDES%NPLWKP_TOT(K)
      ENDDO
      NPLMAX=NPLMAX+LMDIM*NIOND

      IF (IO%IU6>=0) THEN
      WRITE(TIU6,981)'For storing wavefunctions ',1_8*NSUM*WDES%NB_TOT*IO%ICMPLX &
        *WDES%ISPIN/1E6,' MBYTES are necessary'
      WRITE(TIU6,981)'For predicting wavefunctions ', &
     &   1_8*IO%ICMPLX*((WDES%NB_TOT+2)*(NPLMAX*2+3)+GRIDC%MPLWV)*WDES%ISPIN/1E6_q, &
     &   ' MBYTES are necessary'
  981 FORMAT(1X,A,F7.2,A)
      ENDIF
!=======================================================================
! At this very point everything has been read in 
! and we are ready to write all important information
! to the xml file
!=======================================================================
      CALL XML_ATOMTYPES(T_INFO%NIONS, T_INFO%NTYP, T_INFO%NITYP, T_INFO%ITYP, P%ELEMENT, P%POMASS, P%ZVALF, P%SZNAMP )

      CALL XML_TAG("structure","initialpos")
      CALL XML_CRYSTAL(LATT_CUR%A, LATT_CUR%B, LATT_CUR%OMEGA)
      CALL XML_POSITIONS(T_INFO%NIONS, DYN%POSION)
      IF (T_INFO%LSDYN) CALL XML_LSDYN(T_INFO%NIONS,T_INFO%LSFOR(1,1))
      IF (DYN%IBRION<=0 .AND. DYN%NSW>0 ) CALL XML_VEL(T_INFO%NIONS, DYN%VEL)
      IF (T_INFO%LSDYN) CALL XML_NOSE(DYN%SMASS)
      CALL XML_CLOSE_TAG("structure")
!=======================================================================
! initialize index tables for broyden mixing
!=======================================================================
      IF (((MIX%IMIX==4).AND.(.NOT.INFO%LCHCON)).OR.DYN%IBRION==10) THEN
! Use a reduced mesh but only if using preconditioning ... :
         CALL BRGRID(GRIDC,GRIDB,INFO%ENMAX,IO%IU6,LATT_CUR%B)
         CALL INILGRD(GRIDB%NGX,GRIDB%NGY,GRIDB%NGZ,GRIDB)
         CALL GEN_RC_SUB_GRID(GRIDB,GRIDC, B_TO_C, .FALSE.,.TRUE.)
      ENDIF
! calculate the structure-factor, initialize some arrays
      CALL STUFAK(GRIDC,T_INFO,CSTRF)
      CHTOT=0 ; CHDEN=0; CVTOT=0
!=======================================================================
! construct initial  charge density:  a bit of heuristic is used
!  to get sensible defaults if the user specifies stupid values in the
!  INCAR files
! for the initial charge density there are several possibilties
! if INFO%ICHARG= 1 read in charge-density from a File
! if INFO%ICHARG= 2 construct atomic charge-densities of overlapping atoms
! if INFO%ICHARG >=10 keep chargedensity constant
!
!=======================================================================
      ! subtract 10 from ICHARG (10 means fixed charge density)
      IF (INFO%ICHARG>10) THEN
        INFO%INICHG= INFO%ICHARG-10
      ELSE
        INFO%INICHG= INFO%ICHARG
      ENDIF
 
      ! then initialize CRHODE and than RHOLM (PAW related occupancies)
      CALL DEPATO(WDES, LMDIM, CRHODE, INFO%LOVERL, P, T_INFO)
      CALL SET_RHO_PAW(WDES, P, T_INFO, INFO%LOVERL, WDES%NCDIJ, LMDIM, &
           CRHODE, RHOLM)

     ! initial set of wavefunctions from diagonalization of Hamiltonian
     ! set INICHG to 2
      IF (INFO%INICHG==0 .AND. INFO%INIWAV==2) THEN
        INFO%INICHG=2
        IF (IO%IU6>=0) &
        WRITE(TIU6,*)'WARNING: no initial charge-density supplied,', &
                       ' atomic charge-density will be used'
      ENDIF

      IF (INFO%INICHG==1 .OR.INFO%INICHG==2 .OR.INFO%INICHG==3) THEN
      IF (IO%IU6>=0) WRITE(TIU6,*)'initial charge density was supplied:'
      ENDIF

      IF (INFO%INICHG==1) THEN
        
        CALL READCH(GRIDC, INFO%LOVERL, T_INFO, CHTOT, RHOLM, INFO%INICHG, WDES%NCDIJ, &
              LATT_CUR, P, CSTRF(1,1), 18, IO%IU0)
        IF (INFO%ICHARG>10 .AND. INFO%INICHG==0) THEN
           WRITE(*,*)'ERROR: charge density could not be read from file CHGCAR', &
               ' for ICHARG>10'
           STOP
        ENDIF
        ! error on reading CHGCAR, set INFO%INICHG to 2
        IF (INFO%INICHG==0)  INFO%INICHG=2
        ! no magnetization density set it according to MAGMOM
        IF (INFO%INICHG==-1) THEN
           CALL MRHOATO(.FALSE.,GRIDC,T_INFO,LATT_CUR%B,P,CHTOT(1,2),WDES%NCDIJ-1)
           INFO%INICHG=1
           IF( TIU0 >=0) &
           WRITE(TIU0,*)'magnetization density of overlapping atoms calculated'
        ENDIF

      ENDIF

      IF (INFO%INICHG==1) THEN
      ELSE IF (INFO%INICHG==2 .OR.INFO%INICHG==3) THEN

         CALL RHOATO_WORK(.FALSE.,.FALSE.,GRIDC,T_INFO,LATT_CUR%B,P,CSTRF,CHTOT)
         CALL MRHOATO(.FALSE.,GRIDC,T_INFO,LATT_CUR%B,P,CHTOT(1,2),WDES%NCDIJ-1)

         IF (IO%IU6>=0) WRITE(TIU6,*)'charge density of overlapping atoms calculated'
      ELSE
         INFO%INICHG =0
      ENDIF

      
      IF (INFO%INICHG==1 .OR.INFO%INICHG==2 .OR.INFO%INICHG==3) THEN
         DO I=1,WDES%NCDIJ
            RHOTOT(I) =RHO0(GRIDC, CHTOT(1,I))
         ENDDO
         IF(IO%IU6>=0)  WRITE(TIU6,200) RHOTOT(1:WDES%NCDIJ)
 200     FORMAT(' number of electron ',F12.7,' magnetization ',3F12.7)
      ENDIF

      ! set the partial core density
      DENCOR=0
      IF (INFO%LCORE) CALL RHOPAR(GRIDC,T_INFO,LATT_CUR%B,P,CSTRF,DENCOR)

      IF (INFO%INIWAV==2) THEN
         IF (IO%IU0>=0) &
         WRITE(TIU0,*) 'ERROR: this version does not support INIWAV=2'
         STOP
      ENDIF

    IF (IO%IU6>=0) THEN
      IF (INFO%INICHG==0 .OR. (.NOT.INFO%LCHCOS.AND. INFO%NELMDL==0) ) THEN
        WRITE(TIU6,*)'charge density for first step will be calculated', &
         ' from the start-wavefunctions'
      ELSE
        WRITE(TIU6,*)'keeping initial charge density in first step'
      ENDIF
      WRITE(TIU6,130)
    ENDIF

     ! 'atomic charge done'
!========================subroutine SPHER ==============================
! RSPHER calculates the real space projection operators
!    (VOLUME)^.5 Y(L,M)  VNLR(L) EXP(-i r k)
! subroutine SPHER calculates the nonlocal pseudopotential
! multiplied by the spherical harmonics and (1/VOLUME)^.5:
!    1/(VOLUME)^.5 Y(L,M)  VNL(L)
! (routine must be called if the size of the unit cell is changed)
!=======================================================================
      IF (INFO%LREAL) THEN
         CALL RSPHER(GRID,NONLR_S,LATT_CUR)

         INDMAX=0
         DO NI=1,T_INFO%NIONS
            INDMAX=MAX(INDMAX,NONLR_S%NLIMAX(NI))
         ENDDO
         IF (IO%IU6>=0) &
         WRITE(TIU6,*)'Maximum index for non-local projection operator ',INDMAX
      ELSE

         IZERO=1
         CALL SPHER(GRID,NONL_S,P,WDES,LATT_CUR,  IZERO,LATT_INI%B)
         CALL PHASE(WDES,NONL_S,0)

      ENDIF

      ! 'non local setup done'
!=======================================================================
! set up the Hartree-Fock part
!=======================================================================
! this is probably the place where (1._q,0._q) would like to initialise the HF routine


!=======================================================================
! set the coefficients of the plane wave basis states to (0._q,0._q) before
! initialising the wavefunctions by calling WFINIT (usually random)
!=======================================================================
      IF (INFO%ISTART<=0) THEN
        W%CPTWFP=0
        CALL WFINIT(GRID,WDES,W, INFO%ENINI,INFO%INIWAV)
      IF (INFO%INIWAV==1 .AND. INFO%NELMDL==0 .AND. INFO%INICHG/=0) THEN
        IF (IO%IU0>=0) &
        WRITE(TIU0,*) 'WARNING: random wavefunctions but no delay for ', &
                        'mixing, default for NELMDL'
        INFO%NELMDL=-5
        IF (INFO%LRMM .AND. .NOT. INFO%LDAVID) INFO%NELMDL=-12
      ENDIF

      ! initialize the occupancies, in the spin polarized case
      ! we try to set up and down occupancies individually
      ELEKTR=INFO%NELECT
      CALL DENINI(W%FERTOT(1,1,1),WDES%NB_TOT,KPOINTS%NKPTS,ELEKTR)

      IF (WDES%ISPIN==2) THEN
        RHOMAG=RHO0(GRIDC,CHTOT(1,2))
        ELEKTR=INFO%NELECT+RHOMAG
        CALL DENINI(W%FERTOT(1,1,1),WDES%NB_TOT,KPOINTS%NKPTS,ELEKTR)
        ELEKTR=INFO%NELECT-RHOMAG
        CALL DENINI(W%FERTOT(1,1,2),WDES%NB_TOT,KPOINTS%NKPTS,ELEKTR)
      ENDIF

      ENDIF
      ! 'wavefunctions initialized'
!=======================================================================
!  read Fermi-weigths from INCAR if supplied
!=======================================================================
      CALL RDATAB(IO%LOPEN,'INCAR',IO%IU5,'FERWE','=','#',';','F', &
     &     IDUM,W%FERTOT(1,1,1),CDUM,LDUM,CHARAC,N,KPOINTS%NKPTS*WDES%NB_TOT,IERR)
      IF ( ((IERR/=0) .AND. (IERR/=3)) .OR. &
     &     ((IERR==0).AND.(N<(KPOINTS%NKPTS*WDES%NB_TOT)))) THEN
         IF (IO%IU0>=0) &
         WRITE(TIU0,*)'Error reading item ''FERWE'' from file INCAR.'
         STOP
      ENDIF
! attention this feature is not supported by the xml writer
!      CALL XML_INCAR_V('FERWE','F',IDUM,W%FERTOT(1,1,1),CDUM,LDUM,CHARAC,N)

      IF (WDES%ISPIN==2) THEN
         CALL RDATAB(IO%LOPEN,'INCAR',IO%IU5,'FERDO','=','#',';','F', &
     &        IDUM,W%FERTOT(1,1,INFO%ISPIN),CDUM,LDUM,CHARAC,N,KPOINTS%NKPTS*WDES%NB_TOT,IERR)
         IF ( ((IERR/=0) .AND. (IERR/=3)) .OR. &
     &        ((IERR==0).AND.(N<(KPOINTS%NKPTS*WDES%NB_TOT)))) THEN
            IF (IO%IU0>=0) &
            WRITE(TIU0,*)'Error reading item ''FERDO'' from file INCAR.'
            STOP
         ENDIF
! attention this feature is not supported by the xml writer
!         CALL XML_INCAR_V('FERDO','F',IDUM,W%FERTOT(1,1,INFO%ISPIN),CDUM,LDUM,CHARAC,N)
      ENDIF
! if ISMEAR == -2 occupancies will be kept fixed
      IF (KPOINTS%ISMEAR==-2) THEN
         KPOINTS%SIGMA=-ABS(KPOINTS%SIGMA)
      ENDIF
!=======================================================================
! calculate the projections of the wavefunctions onto the projection
! operators using real-space projection scheme or reciprocal scheme
! then performe an orthogonalisation of the wavefunctions
!=======================================================================
!-----first call SETDIJ to set the array CQIJ

      CALL SETDIJ(WDES,GRIDC,GRIDUS,C_TO_US,LATT_CUR,P,T_INFO,INFO%LOVERL, &
                  LMDIM,CDIJ,CQIJ,CVTOT,IRDMAA,IRDMAX,.0_q,.0_q,.0_q)

      ! 'setdij done'

      IF (IO%IU6>=0) &
      WRITE(TIU6,*)'Maximum index for augmentation-charges ', &
                     IRDMAA,'(set IRDMAX)'

      CALL PROALL (GRID,LATT_CUR,NONLR_S,NONL_S,WDES,W,INFO%LOVERL,INFO%LREAL,LMDIM)
      ! 'proall done'

      CALL ORTHCH(WDES,W, INFO%LOVERL, LMDIM,CQIJ,NBLK)
      CALL REDIS_PW_ALL(WDES, W)

      ! 'orthch done'

      IF (IO%IU6>=0) &
      WRITE(TIU6,130)

      ! 'projections done'
!=======================================================================
! INFO%LONESW initialize W_F%CELEN fermi-weights and augmentation charge
!=======================================================================
      IF (INFO%LONESW) THEN

      W_F%CELTOT = W%CELTOT(:,:,1)
      CALL DENSTA( IO%IU0, IO%IU6, WDES, W, KPOINTS, INFO%NELECT, &
               INFO%NUP_DOWN,  E%EENTROPY, EFERMI, KPOINTS%SIGMA, &
               NEDOS, 0, 0, DOS, DOSI, PAR, DOSPAR)
      CALL DEPSUM(W,WDES, LMDIM, CRHODE, INFO%LOVERL)
      CALL US_FLIP(WDES, LMDIM, CRHODE, INFO%LOVERL, .FALSE.)

      ENDIF
!=======================================================================
! partial band dicomposed chargedensities PARDENS
!=======================================================================
      IF (LPARD) THEN
           CALL DENSTA( IO%IU0, IO%IU6, WDES, W, KPOINTS, INFO%NELECT, &
                INFO%NUP_DOWN,  E%EENTROPY, EFERMI, KPOINTS%SIGMA, &
                NEDOS, 0, 0, DOS, DOSI, PAR, DOSPAR)
           CALL PARCHG(W,WUP,WDW,WDES,CHDEN,CHTOT,CRHODE,INFO,GRID, &
                GRID_SOFT,GRIDC,GRIDUS,C_TO_US, &
                LATT_CUR,P,T_INFO,SOFT_TO_C,SYMM,IO, &
                DYN,EFERMI,LMDIM,IRDMAX,NIOND)
      ENDIF
!=======================================================================
! calculate initial chargedensity if
! ) we do not have any chargedensity
! ) we use a selfconsistent minimization scheme and do not have a delay
!=======================================================================
      IF (INFO%INICHG==0 .OR. (.NOT.INFO%LCHCOS.AND. INFO%NELMDL==0)  ) THEN
         IF (IO%IU6>=0) &
              WRITE(TIU6,*)'initial charge from wavefunction'
         
         IF (IO%IU0>=0) &
              WRITE(TIU0,*)'initial charge from wavefunction'

         CALL DEPSUM(W, WDES, LMDIM, CRHODE, INFO%LOVERL)
         CALL US_FLIP(WDES, LMDIM, CRHODE, INFO%LOVERL, .FALSE.)

         CALL SET_CHARGE(W, WUP, WDW, WDES, INFO%LOVERL, &
              GRID, GRIDC, GRID_SOFT, GRIDUS, C_TO_US, SOFT_TO_C, &
              LATT_CUR, P, SYMM, T_INFO, &
              CHDEN, LMDIM, CRHODE, CHTOT, RHOLM, N_MIX_PAW, IRDMAX)
      ENDIF

!=======================================================================
! initialise the predictor for the wavefunction with
! the first available ionic positions
! PRED%INIPRE=2 continue with existing file
! PRED%INIPRE=1 initialise
!=======================================================================
      IF (INFO%ISTART==3) THEN
        PRED%INIPRE=2
      ELSE
        PRED%INIPRE=1
      ENDIF

      IF (DYN%IBRION/=-1 .AND. PRED%IWAVPR >= 12 ) THEN
        CALL WAVPRE_NOIO(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
           CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)
      ELSE IF (DYN%IBRION/=-1 .AND. PRED%IWAVPR >= 2 .AND. PRED%IWAVPR <10 )  THEN
        CALL WAVPRE(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
           CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)
      ENDIF
      ! "wavpre is ok"

!=======================================================================
! if INFO%IALGO < 0 make some performance tests
!=======================================================================
      IF (INFO%IALGO<0) GOTO 5000

!======================== SUBROUTINE FEWALD ============================
! calculate ewald energy forces, and stress
!=======================================================================
      CALL VTIME(TV0,TC0)
      CALL FEWALD(DYN%POSION,EWIFOR,LATT_CUR%A,LATT_CUR%B,LATT_CUR%ANORM,LATT_CUR%BNORM, &
     &     LATT_CUR%OMEGA,EWSIF,E%TEWEN,T_INFO%NTYP,P%ZVALF,T_INFO%NIONS,NIOND,T_INFO%ITYP,T_INFO%NITYP,IO%IU6)
      CALL VTIME(TV,TC)

      IF (IO%NWRITE>=2.AND. IO%IU6>=0) WRITE(TIU6,2300)'FEWALD',TV-TV0,TC-TC0
 2300 FORMAT(2X,A8,':  VPU time',F8.2,': CPU time',F8.2)

! before entering the main loop reopen the WAVECAR file in the new format
! no matter what format we used before for reading it ...
      NPL_TOT=MAXVAL(WDES%NPLWKP_TOT)
      IRECLW=MAX(MAX((NPL_TOT+1)/2,6),(WDES%NB_TOT+2))*ICMPLX
      CLOSE(12)
      OPEN(UNIT=12,FILE=DIR_APP(1:DIR_LEN)//'WAVECAR',ACCESS='DIRECT', &
                   FORM='UNFORMATTED',STATUS='UNKNOWN',RECL=IRECLW)

!=======================================================================
! set INFO%LPOTOK to false: this requires  a recalculation of the
! total lokal potential
!=======================================================================
      INFO%LPOTOK=.FALSE.
      TOTENG=0
      INFO%LSTOP=.FALSE.
      INFO%LSOFT=.FALSE.

      IF (IO%IU0>=0) &
           WRITE(TIU0,*)'entering main loop'

!***********************************************************************
!***********************************************************************
!
! ++++++++++++ do 1000 n=1,required number of timesteps ++++++++++++++++
!
! this is the main loop of the program during which (1._q,0._q) complete step of
! the electron dynamics and ionic movements is performed.
! NSTEP           loop counter for ionic movement
! N               loop counter for self-consistent loop
! INFO%NELM            number of electronic movement loops
!***********************************************************************
!***********************************************************************
      NSTEP = 0
      CALL VTIME(TVPUL0,TCPUL0)

!-MM- Added to accomodate constrained moment calculations etc
      CALL CONSTRAINED_M_INIT(T_INFO,GRIDC,LATT_CUR)
      CALL INIT_WRITER(P,T_INFO,WDES)
!-MM- end of additions

!=======================================================================
      ion: DO
      IF (INFO%LSTOP) EXIT ion
!=======================================================================

!  reset broyden mixing
      MIX%LRESET=.TRUE.
!  last energy
      TOTENL=0
      IF (IO%LOPEN) CALL WFORCE(IO%IU6)

!=======================================================================
! initialize pair-correlation funtion to (0._q,0._q)
! also set TMEAN und SMEAN to (0._q,0._q)
! TMEAN/SMEAN  is the mean temperature
!=======================================================================
      IF (MOD(NSTEP,DYN%NBLOCK*DYN%KBLOCK)==0) THEN
        SMEANP=0
        PACO%SIPACO=0
        TMEAN=0
        TMEAN0=0
        SMEAN=0
        SMEAN0=0
        DDOSI=0._q
        DDOS =0._q
      ENDIF

      NSTEP = NSTEP + 1
      IF (INFO%NELM==0 .AND. IO%IU6>=0) WRITE(TIU6,140) NSTEP,0

!***********************************************************************
!***********************************************************************
! this part performs the total energy minimisation
! INFO%NELM loops are made, if the difference between two steps
! is less then INFO%EDIFF the loop is aborted
!***********************************************************************
!***********************************************************************
      CALL XML_TAG("calculation")

      CALL ELMIN( &
          P,WDES,NONLR_S,NONL_S,W,W_F,W_G,WUP,WDW,LATT_CUR,LATT_INI,EXCTAB, &
          T_INFO,DYN,INFO,IO,MIX,KPOINTS,SYMM,GRID,GRID_SOFT, &
          GRIDC,GRIDB,GRIDUS,C_TO_US,B_TO_C,SOFT_TO_C,DIP,E,E2, &
          CHTOT,CHTOTL,DENCOR,CVTOT,CSTRF, &
          CDIJ,CQIJ,CRHODE,N_MIX_PAW,RHOLM,RHOLM_LAST, &
          CHDEN,SV,DOS,DOSI,CHF,CHAM,DESUM,XCSIF, &
          NSTEP,NELMLS,LMDIM,NIOND,IRDMAX,NBLK,NEDOS, &
          TOTEN,TOTENL,EFERMI,LDIMP,LMDIMP,LTRUNC)

      
!  'soft stop': stop after the next ionic step finished
!  in order to do this create file STOPCAR and set an entry INFO%LSTOP=.TRUE.
      LTMP=.FALSE.
      CALL RDATAB(IO%LOPEN,'STOPCAR',99,'LSTOP','=','#',';','L', &
     &            IDUM,RDUM,CDUM,LTMP,CHARAC,NCOUNT,1,IERR)
      IF (LTMP) THEN
        IF (IO%IU0>=0) &
             WRITE(TIU0,*) 'soft stop encountered!  aborting job ...'
        IF (IO%IU6>=0) &
        WRITE(TIU6,*) 'soft stop encountered!  aborting job ...'

        INFO%LSOFT=.TRUE.
      ENDIF

!=======================================================================
! Do some check for occupation numbers (do we have enough bands]:
!=======================================================================
      IOCCUP=0
      IOCCVS=0
      SUMNEL=0._q
      DO ISP=1,WDES%ISPIN
      DO NN=1,KPOINTS%NKPTS
         IF (ABS(W%FERTOT(WDES%NB_TOT,NN,ISP))>1.E-2_q) THEN
            IOCCUP=IOCCUP+1
! total occupancy ('number of electrons in this band'):
            SUMNEL=SUMNEL+WDES%RSPIN*W%FERTOT(WDES%NB_TOT,NN,ISP)*KPOINTS%WTKPT(NN)
            IF (IOCCUP<NTUTOR) THEN
               ITUT(IOCCUP)=NN
               RTUT(IOCCUP)=W%FERTOT(WDES%NB_TOT,NN,ISP)
            ENDIF
         ENDIF
! count seperately 'seriously large occupations' ...
         IF (ABS(W%FERTOT(WDES%NB_TOT,NN,ISP))>2.E-1_q) IOCCVS=IOCCVS+1
      ENDDO
      ENDDO

      IF (((IOCCUP/=0).AND.(SUMNEL>1E-3_q)).OR.(IOCCVS/=0)) THEN
         IOCC=MIN(IOCCUP+1,NTUTOR)
         ITUT(IOCC)=WDES%NB_TOT
         RTUT(IOCC)=SUMNEL
         CALL VTUTOR('U','HIGHEST BANDS OCCUPIED', &
     &               RTUT,IOCC,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
         CALL VTUTOR('U','HIGHEST BANDS OCCUPIED', &
     &               RTUT,1,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
! no matter how the IO%IDIOT-flag is set: for seriously large occupations
! give always a message to the user because this is very important!!
         IF ((IO%IDIOT<=0).AND.((IOCCVS/=0).OR.(SUMNEL>1E-2_q))) THEN
            CALL VTUTOR('U','HIGHEST BANDS OCCUPIED', &
     &                  RTUT,IOCC,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU6,1)
            CALL VTUTOR('U','HIGHEST BANDS OCCUPIED', &
     &                  RTUT,1,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU0,1)
         ENDIF
      ELSE IF (IOCCUP/=0) THEN
! for less serious occupancies give just some 'good advice' ...
         IOCC=MIN(IOCCUP+1,NTUTOR)
         ITUT(IOCC)=WDES%NB_TOT
         RTUT(IOCC)=SUMNEL
         CALL VTUTOR('A','HIGHEST BANDS OCCUPIED', &
     &               RTUT,IOCC,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
         CALL VTUTOR('A','HIGHEST BANDS OCCUPIED', &
     &               RTUT,1,ITUT,IOCC,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ENDIF

! Okay when we arrive here first then we got it for the first ionic
! configuration and if more steps follow we might not need any further
! 'delay' switching on the selfconsistency? (if NELMDL<0 switch off!).
      IF (INFO%NELMDL<0) INFO%NELMDL=0

      IF (IO%LORBIT>=10) THEN
         CALL SPHPRO_FAST( &
          GRID,LATT_CUR,LATT_INI, P,T_INFO,W, WDES, 71,IO%IU6,&
          INFO%LOVERL,LMDIM,CQIJ, LDIMP, LDIMP,LMDIMP,.FALSE., IO%LORBIT,PAR)
      ENDIF
!***********************************************************************
!***********************************************************************
! Now perform the ion movements:
!***********************************************************************
!***********************************************************************
!====================== FORCES+STRESS ==================================
!
!=======================================================================

!-----------------------------------------------------------------------
! we have maybe to update CVTOT here (which might have been destroyed)
!-----------------------------------------------------------------------

      IF (.NOT.INFO%LPOTOK) THEN

      CALL VTIME(TV0,TC0)

      CALL POTLOK(GRID,GRIDC,GRID_SOFT, WDES%COMM_INTER, WDES,  &
                  EXCTAB,INFO,P,T_INFO,E,LATT_CUR,DIP, &
                  CHTOT,CSTRF,CVTOT,DENCOR,SV, SOFT_TO_C,XCSIF)

      CALL SETDIJ(WDES,GRIDC,GRIDUS,C_TO_US,LATT_CUR,P,T_INFO,INFO%LOVERL, &
                  LMDIM,CDIJ,CQIJ,CVTOT,IRDMAA,IRDMAX,.0_q,.0_q,.0_q)

      CALL SET_DD_PAW(WDES, P , T_INFO, INFO%LOVERL, &
         WDES%NCDIJ, LMDIM, CDIJ, RHOLM, CRHODE, INFO%LEXCH, INFO%LEXCHG, &
          E, LMETA =  .FALSE., LASPH =.FALSE. , LCOREL=.FALSE.)


      CALL VTIME(TV,TC)

      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'POTLOK',TV-TV0,TC-TC0

      ENDIF

!=======================================================================
!
!  electronic polarisation
! 
!=======================================================================
      IF (LBERRY) THEN
      
         IF (IO%IU6>=0) THEN
            WRITE(TIU6,7230) IGPAR,NPPSTR
         ENDIF
      
         CALL BERRY(WDES,W,GRID,GRIDC,GRIDUS,C_TO_US,LATT_CUR,KPOINTS, &
           IGPAR,NPPSTR,P,T_INFO,LMDIM,CQIJ,IRDMAX,NBLK,INFO%LOVERL,IO%IU6, &
           DIP%POSCEN)
      ENDIF

 7230 FORMAT(/' Berry-Phase calculation of electronic polarization'// &
     &        '   IGPAR = ',I1,'   NPPSTR = ',I4/)
      IF (IO%IU6>=0) WRITE(TIU6,130)

!      IF (LWANNIER()) THEN
!         CALL LOCALIZE(W,WDES,GRID,GRIDC,GRIDUS,C_TO_US,LATT_CUR,T_INFO,P, &
!        &     LMDIM,INFO%LOVERL,IRDMAX,NBLK,IO%IU0,IO%IU6)
!      ENDIF

!-----------------------------------------------------------------------
!  first set CHTOTL to CHTOT
!  if charge-density remains constant during electronic minimization
!  or Harris corrections to forces are calculates
!  set CHTOT to the chargedensity derived from the current
!  wavefunctions
!-----------------------------------------------------------------------
      CALL VTIME(TV0,TC0)

      DO ISP=1,WDES%NCDIJ
      CALL RC_ADD(CHTOT(1,ISP),1.0_q,CHTOT(1,ISP),0.0_q,CHTOTL(1,ISP),GRIDC)
      ENDDO
      RHOLM_LAST=RHOLM

      IF (INFO%LCHCON.OR.INFO%LCORR) THEN

         CALL DEPSUM(W, WDES, LMDIM, CRHODE, INFO%LOVERL)
         CALL US_FLIP(WDES, LMDIM, CRHODE, INFO%LOVERL, .FALSE.)

         CALL SET_CHARGE(W, WUP, WDW, WDES, INFO%LOVERL, &
              GRID, GRIDC, GRID_SOFT, GRIDUS, C_TO_US, SOFT_TO_C, &
              LATT_CUR, P, SYMM, T_INFO, &
              CHDEN, LMDIM, CRHODE, CHTOT, RHOLM, N_MIX_PAW, IRDMAX)

         CALL VTIME(TV,TC)
         IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'CHARGE',TV-TV0,TC-TC0
      ENDIF

!----------------------- FORCES ON IONS    -----------------------------
! calculate the hellmann-feynman forces exerted on the ions
! FORLOC local part
! FORNL  forces due to the non-local part
! FORDEP forces due to augmentation charges
!-----------------------------------------------------------------------
      EIFOR=0; EINL=0; HARFOR=0; PARFOR=0

!     local contribution to force
      CALL VTIME(TV0,TC0)

      CALL FORLOC(GRIDC,P,T_INFO,LATT_CUR, CHTOT,EIFOR)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'FORLOC',TV-TV0,TC-TC0

!     non local contribution to force
      CALL VTIME(TV0,TC0)

      IF (INFO%LREAL) THEN
        CALL FORNLR(GRID,NONLR_S,P,LATT_CUR,W,WDES, &
     &      LMDIM,NIOND,CDIJ,CQIJ, EINL)
      ELSE
        CALL FORNL(NONL_S,WDES,W,LATT_CUR, LMDIM,NIOND,CDIJ,CQIJ,EINL)
      ENDIF


!     force from augmentation part
      IF (INFO%LOVERL) &
      CALL FORDEP(WDES, GRIDC,GRIDUS,C_TO_US, &
         LATT_CUR,P,T_INFO, INFO%LOVERL, &
         LMDIM, CDIJ, CQIJ,CRHODE, CVTOT, IRDMAX, EINL)
      CALL VTIME(TV,TC)
      IF (SYMM%ISYM>0) &
           CALL FORSYM(EINL,SYMM%ROTMAP,T_INFO%NTYP,T_INFO%NITYP,NIOND,SYMM%TAUROT,SYMM%WRKROT,LATT_CUR%A)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'FORNL ',TV-TV0,TC-TC0

      CALL SET_DD_PAW(WDES, P , T_INFO, INFO%LOVERL, &
           WDES%NCDIJ, LMDIM, CDIJ(1,1,1,1), RHOLM,  &
           CRHODE, INFO%LEXCH, INFO%LEXCHG, &
           E, LMETA =  .FALSE., LASPH =.FALSE. , LCOREL=.FALSE. )
!------------------- STRESS ON UNIT CELL -------------------------------
! calculate the stress on the unit cell which is related
! to the change in local pseudopotential on changing the size of
! the cell
! then calculate the non-local contribution to the stress
!-----------------------------------------------------------------------


      IF (DYN%ISIF/=0) THEN
      AUGSIF=0; FNLSIF=0

      CALL VTIME(TV0,TC0)

!      kinetic energy
      CALL STRKIN(W,WDES, LATT_CUR%B,SIKEF)
!     local part
      CALL STRELO(GRIDC,P,T_INFO,LATT_CUR, &
           CHTOT,CSTRF, INFO%NELECT, DSIF,EISIF,PSCSIF)
!     non-local part
      IF (INFO%LREAL) THEN
        CALL STRNLR(GRID,NONLR_S,P,LATT_CUR,W,WDES, &
     &      LMDIM,NIOND,CDIJ,CQIJ, DYN%ISIF,FNLSIF)
      ELSE
        CALL STRENL(GRID,NONL_S,P,W,WDES,LATT_CUR,  LATT_INI%B, &
            LMDIM,NIOND,CDIJ,CQIJ, DYN%ISIF,FNLSIF)
      ENDIF


!     augmentation part
      IF (INFO%LOVERL) &
      CALL STRDEP(WDES, GRIDC,GRIDUS,C_TO_US, &
       LATT_CUR,P,T_INFO, INFO%LOVERL, &
       LMDIM,CDIJ,CQIJ,CRHODE, CVTOT, IRDMAX, DYN%ISIF,AUGSIF)
      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'STRESS',TV-TV0,TC-TC0

      ENDIF

!-----------------------------------------------------------------------
! mind following calls destroy CVTOT
! additional stress due to gradient corrections in the XC-functional
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
! additional forces from partial core corrections
! remark for stress:
! stress deriving from the 1/volume dependency is treated in POTEX
! (this is necessary due to gradient corrections)
!-----------------------------------------------------------------------
      IF (INFO%LCORE) THEN
       CALL VTIME(TV0,TC0)


       CALL POTXC(EXCTAB,GRIDC,INFO,WDES, LATT_CUR, CVTOT(1,1),CHTOT(1,1),DENCOR)
       CALL FORHAR(GRIDC,P,T_INFO,LATT_CUR, &
             CVTOT,PARFOR,.TRUE.)

      IF (DYN%ISIF/=0) THEN

       CALL STREHAR(GRIDC,P,T_INFO,LATT_CUR,.TRUE.,CVTOT,CSTRF, PARSIF)
       XCSIF=XCSIF+PARSIF

      ENDIF

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'FORCOR',TV-TV0,TC-TC0

      ENDIF

!-----------------------------------------------------------------------
! additional forces and stress for Harris-functional
! with moving atomic charge-densities
! this is only correct for paramagnetic LDA calculations
! but because Hartree term accounts for 90 % its almost ok
!-----------------------------------------------------------------------
      IF (INFO%LCHCON.OR.INFO%LCORR) THEN
      CALL VTIME(TV0,TC0)

      CALL CHGGRA(GRIDC,LATT_CUR,EXCTAB, CVTOT,CHTOT,CHTOTL,DENCOR)

      CALL FORHAR(GRIDC,P,T_INFO,LATT_CUR, &
             CVTOT,HARFOR,.FALSE.)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'FORHAR',TV-TV0,TC-TC0
!-----ENDIF (INFO%LCHCON.OR.INFO%LCORR)
      ENDIF
!-----------------------------------------------------------------------
!    if Harris corrections are calculated and if mixing is selected
!    mix now (this improves extrapolation of charge)
!    in all other cases set CHTOT back to CHTOTL
!-----------------------------------------------------------------------
      IF (INFO%LCORR .AND. .NOT. INFO%LCHCON  .AND. MIX%IMIX/=0 ) THEN
      CALL VTIME(TV0,TC0)
      IF (MIX%IMIX==4) THEN
!  broyden mixing ... :
      IF (DYN%IBRION/=10) THEN
      CALL BRMIX(GRIDB,GRIDC,IO,MIX,B_TO_C, &
         (2*GRIDC%MPLWV),CHTOT,CHTOTL,WDES%NCDIJ,LATT_CUR%B, &
         LATT_CUR%OMEGA, N_MIX_PAW, RHOLM, RHOLM_LAST, &
         RMST,RMSC,RMSP,WEIGHT,IERRBR)
        IF (IERRBR/=0) THEN
           IF (IO%IU0>=0) &
           WRITE(TIU0,*) 'ERROR: Broyden mixing failed, tried ''simple '// &
     &                 'mixing'' now and reset mixing at next step!'
           WRITE(TIU6,*) 'ERROR: Broyden mixing failed, tried ''simple '// &
     &                 'mixing'' now and reset mixing at next step!'
        ENDIF
      ENDIF
      ELSE
!  simple mixing
      RMST=0
      CALL MIX_SIMPLE(GRIDC,MIX,WDES%NCDIJ, CHTOT,CHTOTL, &
           N_MIX_PAW, RHOLM, RHOLM_LAST, LATT_CUR%B, LATT_CUR%OMEGA, RMST)
      ENDIF
      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0)WRITE(TIU6,2300)'MIXING',TV-TV0,TC-TC0

      ELSE
!-----------------------------------------------------------------------
!     all other cases: restore CHTOT from CHTOTL
      DO ISP=1,WDES%NCDIJ
      CALL RC_ADD(CHTOTL(1,ISP),1.0_q,CHTOTL(1,ISP),0.0_q,CHTOT(1,ISP),GRIDC)
      ENDDO
      RHOLM=RHOLM_LAST
!---- ENDIF (MIX%IMIX==4)
      ENDIF
!-----------------------------------------------------------------------
! ) sum total force on cell
! ) sum the total force on the ions
! ) remove spurios drift SYMVEC, and symmetrisation of forces
!-----------------------------------------------------------------------

      TSIF=0
      IF (DYN%ISIF/=0) THEN
        TSIF=SIKEF+EWSIF+EISIF+PSCSIF+XCSIF+DSIF+FNLSIF+AUGSIF
        IF (SYMM%ISYM>0) CALL TSYM(TSIF,ISYMOP,NROTK,LATT_CUR%A)
      ENDIF
! average STRESS add Pullay term
      PRESS=(TSIF(1,1)+TSIF(2,2)+TSIF(3,3))/3._q &
     &      -DYN%PSTRESS/(EVTOJ*1E22_q)*LATT_CUR%OMEGA

!-----------------------------------------------------------------------
      IF ( DIP%IDIPCO >0 ) THEN
         EIFOR=EIFOR+DIP%FORCE
      ENDIF
      TIFOR=EIFOR+EWIFOR+EINL+HARFOR+PARFOR

!      IF (DYN%IBRION/=0 .OR. LCOMPAT) THEN
! remove drift from the forces
        CALL SYMVEC(T_INFO%NIONS,TIFOR)
!      ENDIF
! symmetrization of forces:
      IF (SYMM%ISYM>0) &
     &        CALL FORSYM(TIFOR,SYMM%ROTMAP,T_INFO%NTYP,T_INFO%NITYP,NIOND,SYMM%TAUROT,SYMM%WRKROT,LATT_CUR%A)

      

! check the consistency of forces and total energy
      CALL CHECK(T_INFO%NIONS,DYN%POSION,TIFOR,EWIFOR,TOTEN,E%TEWEN,LATT_CUR%A,IO%IU6)

!=======================================================================
! write out energy, stress and forces on ions
!=======================================================================
      TOTEN=TOTEN
      NORDER=0
      IF (KPOINTS%ISMEAR>=0) NORDER=KPOINTS%ISMEAR

      
      WRITE(TIU6,130)
      WRITE(TIU6,7261) TOTEN,TOTEN-E%EENTROPY,TOTEN-E%EENTROPY/(2+NORDER)
      

 7261 FORMAT(/ &
     &        '  FREE ENERGIE OF THE ION-ELECTRON SYSTEM (eV)'/ &
     &        '  ---------------------------------------------------'/ &
     &        '  free  energy   TOTEN  = ',F16.6,' eV'// &
     &        '  energy  without entropy=',F16.6, &
     &        '  energy(sigma->0) =',F16.6)

      IF (DYN%PSTRESS/=0) THEN
        TOTEN=TOTEN+DYN%PSTRESS/(EVTOJ*1E22_q)*LATT_CUR%OMEGA

        IF (IO%IU6>=0) &
        WRITE(TIU6,7264) TOTEN,DYN%PSTRESS/(EVTOJ*1E22_q)*LATT_CUR%OMEGA
 7264   FORMAT ('  enthalpy is  TOTEN    = ',F16.6,' eV   P V=',F16.6/)

      ELSE
         IF (IO%IU6>=0) &
         WRITE(TIU6,*)
      ENDIF

      IF (DYN%ISIF/=0) THEN
      FAKT=EVTOJ*1E22_q/LATT_CUR%OMEGA

      IF (IO%IU6>=0) THEN
      IF (DYN%ISIF==1) &
     &WRITE(TIU6,*)'only uniform nonlocal contributions calculated', &
     &          ' for stress because ISIF=1'

      WRITE(TIU6,7262) (PSCSIF(I,I),I=1,3), &
     &     (EWSIF(I,I),I=1,3),EWSIF(1,2),EWSIF(2,3),EWSIF(3,1), &
     &     (DSIF (I,I),I=1,3),DSIF (1,2),DSIF (2,3),DSIF (3,1), &
     &     (XCSIF(I,I),I=1,3),XCSIF(1,2),XCSIF(2,3),XCSIF(3,1), &
     &     (EISIF(I,I),I=1,3),EISIF(1,2),EISIF(2,3),EISIF(3,1), &
     &     (FNLSIF(I,I),I=1,3),FNLSIF(1,2),FNLSIF(2,3),FNLSIF(3,1), &
     &     (AUGSIF(I,I),I=1,3),AUGSIF(1,2),AUGSIF(2,3),AUGSIF(3,1), &
     &     (SIKEF(I,I),I=1,3),SIKEF(1,2),SIKEF(2,3),SIKEF(3,1), &
     &     (TSIF (I,I),I=1,3),TSIF (1,2),TSIF (2,3),TSIF (3,1), &
     &     (TSIF (I,I)*FAKT,I=1,3), &
     &     TSIF(1,2)*FAKT,TSIF(2,3)*FAKT, &
     &     TSIF(3,1)*FAKT,PRESS*FAKT,DYN%PSTRESS
      ENDIF

 7262 FORMAT(/ &
     &        '  FORCE on cell =-STRESS in cart. coord. ' &
     &       ,' units (eV/reduce length):'/ &
     &        '  Direction', &
     &        4X,'X', 8X,'Y', 8X,'Z', 8X,'XY', 7X,'YZ', 7X,'ZX'/ &
     &        '  ----------------------------------------------------', &
     &        '----------------------------------'/ &
     &        '  Alpha Z',3F10.2/ &
     &        '  Ewald  ',6F10.2/ &
     &        '  Hartree',6F10.2/ &
     &        '  E(xc)  ',6F10.2/ &
     &        '  Local  ',6F10.2/ &
     &        '  n-local',6F10.2/ &
     &        '  augment',6F10.2/ &
     &        '  Kinetic',6F10.2/ &
     &        '  ---------------------------------------------------', &
     &        '----------------------------------'/ &
     &        '  Total  ',6F10.2/ &
     &        '  in kB  ',6F10.2/ &
     &        '  external pressure = ',F11.2,' kB', &
     &        '  Pullay stress = ',F11.2,' kB'/)

      ENDIF

      
      wrtforce: IF ((NSTEP==1 .OR.NSTEP==DYN%NSW).OR.IO%NWRITE>=1) THEN

        WRITE(TIU6,7263)
 7263 FORMAT(/' VOLUME and BASIS-vectors are now :'/ &
     &        ' ------------------------------------------------------', &
     &        '-----------------------')

        WRITE(TIU6,7220) INFO%ENMAX,LATT_CUR%OMEGA, &
     &    ((LATT_CUR%A(I,J),I=1,3),(LATT_CUR%B(I,J),I=1,3),J=1,3), &
     &    (LATT_CUR%ANORM(I),I=1,3),(LATT_CUR%BNORM(I),I=1,3)

        TEIFOR=0;  TEWIFO=0; TFORNL=0 ; THARFO=0

        DO J=1,T_INFO%NIONS
        DO I=1,3
          TEIFOR(I)=TEIFOR(I)+EIFOR (I,J)+PARFOR(I,J)
          TEWIFO(I)=TEWIFO(I)+EWIFOR(I,J)
          TFORNL(I)=TFORNL(I)+EINL (I,J)
          THARFO(I)=THARFO(I)+HARFOR(I,J)
        ENDDO
        ENDDO

        IF (INFO%LCHCON.OR.INFO%LCORR) THEN
        WRITE(TIU6,71) ((EIFOR (I,J)+PARFOR(I,J),I=1,3), &
     &                 (EWIFOR(I,J),I=1,3), &
     &                 (EINL (I,J),I=1,3), &
     &                 (HARFOR(I,J),I=1,3),J=1,T_INFO%NIONS)

        WRITE(TIU6,73) (TEIFOR(I),I=1,3), &
     &                (TEWIFO(I),I=1,3), &
     &                (TFORNL(I),I=1,3), &
     &                (THARFO(I),I=1,3)

        ELSE
        WRITE(TIU6,75) ((EIFOR (I,J),I=1,3), &
     &                 (EWIFOR(I,J),I=1,3), &
     &                 (EINL (I,J),I=1,3),J=1,T_INFO%NIONS)

        WRITE(TIU6,73) (TEIFOR(I),I=1,3), &
     &                (TEWIFO(I),I=1,3), &
     &                (TFORNL(I),I=1,3)

        ENDIF
 73     FORMAT(' ---------------------------------------------------', &
     &         '--------------------------------------------'/ &
     &          4(2X,3(1X,E9.3)))

 71     FORMAT(' FORCES acting on ions'/ &
     &    3X,' electron-ion (+dipol)',12X,'ewald-force',20X,'non-local-force',&
     &    16X,' convergence-correction' / &
     &         ' ---------------------------------------------------', &
     &         '--------------------------------------------'/ &
     &      4(2X,3(1X,E9.3)) )

 75     FORMAT(' FORCES acting on ions:'/ &
     &    3X,' Electron-Ion ',20X,'Ewald-Force',20X,'Non-Local-Force'/ &
     &         ' ---------------------------------------------------', &
     &         '--------------------------------------------'/ &
     &    3(2X,3(1X,E9.3)))

        WRITE(TIU6,*)
        WRITE(TIU6,*)


      WRITE(TIU6,72)
      DO J=1,T_INFO%NIONS
        VTMP=DYN%POSION(1:3,J)
        CALL  DIRKAR(1,VTMP,LATT_CUR%A)
        WRITE(TIU6,76) VTMP,(TIFOR (I,J),I=1,3)
      ENDDO

 72     FORMAT( ' POSITION    ',35X,'TOTAL-FORCE (eV/Angst)'/ &
     &          ' ----------------------------------------------', &
     &          '-------------------------------------')
 76     FORMAT((3F13.5,3X,3F14.6))


        VTMP=TEIFOR+TEWIFO+TFORNL+THARFO

        WRITE(TIU6,74) VTMP

 74     FORMAT( ' ----------------------------------------------', &
     &          '-------------------------------------',/ &
     &          '    total drift:      ',20X,3F14.6)

        WRITE(TIU6,130)
      ENDIF wrtforce
      

      CALL XML_TAG("structure")
      CALL XML_CRYSTAL(LATT_CUR%A, LATT_CUR%B, LATT_CUR%OMEGA)
      CALL XML_POSITIONS(T_INFO%NIONS, DYN%POSION)
      CALL XML_CLOSE_TAG("structure")
      CALL XML_FORCES(T_INFO%NIONS, TIFOR)
      IF (DYN%ISIF/=0) THEN
         CALL XML_STRESS(TSIF*FAKT)
      ENDIF
!=======================================================================
! add chain forces and constrain forces
!=======================================================================
      IF (DYN%IBRION /=5) &
      CALL SET_SELECTED_FORCES_ZERO(T_INFO,DYN%VEL,TIFOR,LATT_CUR)

      CALL CHAIN_FORCE(T_INFO%NIONS,DYN%POSION,TOTEN,TIFOR, &
           LATT_CUR%A,LATT_CUR%B,IO%IU6)

      IF (DYN%IBRION /=5) &
      CALL SET_SELECTED_FORCES_ZERO(T_INFO,DYN%VEL,TIFOR,LATT_CUR)

      EKIN=0
      TEIN=0
      ES =0
      EPS=0

!     CYCLE ion ! if uncommented VASP iterates forever without ionic upd

      DO I=1,WDES%NCDIJ
         RHOTOT(I)=RHO0(GRIDC, CHTOT(1,I))
      END DO
!=======================================================================
! IBRION = -1 static
! IBRION = 0  molecular dynamics
! ------------------------------
! ) calculate the accelerations in reduced units
!   the scaling is brain-damaging, so here it is in a more native form
!    convert dE/dr from EV/Angst to J/m   EVTOJ/1E-10
!    divide by mass                       1/T_INFO%POMASS*AMTOKG
!    multiply by timestep*2               (DYN%POTIM*1E-15)**2
! ) transform to direct mesh KARDIR
! ) integrate the equations of motion for the ions using nose dynamic
!   and a predictor-corrector scheme
!=======================================================================
      DYN%AC=  LATT_CUR%A

      IF (DYN%IBRION/=0) THEN
         CALL XML_TAG("energy")
         CALL XML_ENERGY(TOTEN,TOTEN-E%EENTROPY/(2+NORDER),E%EENTROPY)
         CALL XML_CLOSE_TAG
      ENDIF

      ibrion: IF (DYN%IBRION==-1) THEN
         
         WRITE(17 ,7281,ADVANCE='NO') NSTEP,TOTEN, &
              TOTEN-E%EENTROPY/(2+NORDER),E%EENTROPY
         IF (IO%IU0>=0) &
              WRITE(TIU0,7281,ADVANCE='NO') NSTEP,TOTEN, &
              TOTEN-E%EENTROPY/(2+NORDER),E%EENTROPY

         IF ( WDES%NCDIJ>=2 ) THEN
           WRITE(17,77281) RHOTOT(2:WDES%NCDIJ)
           IF (IO%IU0>=0) WRITE(TIU0,77281) RHOTOT(2:WDES%NCDIJ)
         ELSE
           WRITE(17,*)
           IF (IO%IU0>=0) WRITE(TIU0,*)
         ENDIF
! aspherical contribution and metagga (Robin Hirschl)
         IF (INFO%LASPH) THEN
            WRITE(17,72811) NSTEP,E%TOTENASPH, &
                 E%TOTENASPH-E%EENTROPY/(2+NORDER)
            IF (IO%IU0>=0) WRITE(TIU0,72811)NSTEP,E%TOTENASPH, &
                 E%TOTENASPH-E%EENTROPY/(2+NORDER)
         ENDIF
         IF (INFO%LMETAGGA) THEN
           WRITE(17,72812) NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) WRITE(TIU0,72812)NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
         ENDIF
!-MM- Added to accomodate constrained moment calculations
      IF (M_CONSTRAINED()) CALL WRITE_CONSTRAINED_M(17,.TRUE.)
!-MM- end of additions
         

72811 FORMAT(I4,' F(ASPHER.)= ',E14.8,' E0(ASPHER.)= ',E14.8)
72812 FORMAT(I4,' F(METAGGA)= ',E14.8,' E0(METAGGA)= ',E14.8)

      ELSE IF (DYN%IBRION==0 ) THEN ibrion

        FACT=(DYN%POTIM**2)*EVTOJ/AMTOKG *1E-10_q
        NI=1
        DO NT=1,T_INFO%NTYP
        DO NI=NI,T_INFO%NITYP(NT)+NI-1
          DYN%D2C(1,NI)=TIFOR(1,NI)*FACT/2/T_INFO%POMASS(NT)
          DYN%D2C(2,NI)=TIFOR(2,NI)*FACT/2/T_INFO%POMASS(NT)
          DYN%D2C(3,NI)=TIFOR(3,NI)*FACT/2/T_INFO%POMASS(NT)
        ENDDO; ENDDO

        CALL KARDIR(T_INFO%NIONS,DYN%D2C,LATT_CUR%B)

        ISCALE=0
        IF (DYN%SMASS==-1 .AND. MOD(NSTEP-1,DYN%NBLOCK)==0 ) THEN
          ISCALE=1
        ENDIF

        DYN%TEMP=DYN%TEBEG+(DYN%TEEND-DYN%TEBEG)*NSTEP/ABS(DYN%NSW)

!        CALL SYMVEL (T_INFO%NIONS,T_INFO%NTYP,T_INFO%ITYP,T_INFO%POMASS, &
!           DYN%POSION,DYN%D2C,LATT_CUR%A,LATT_CUR%B)

        CALL STEP(DYN%INIT,ISCALE,T_INFO%NIONS,LATT_CUR%A,LATT_CUR%ANORM,DYN%D2C,DYN%SMASS,DYN%POSION,DYN%POSIOC, &
             DYN%POTIM,T_INFO%POMASS,T_INFO%NTYP,T_INFO%ITYP,DYN%TEMP,DYN%VEL,DYN%D2,DYN%D3,DYN%SNOSE, &
             EKIN,EPS,ES,DISMAX,NDEGREES_OF_FREEDOM, IO%IU6)
        TEIN = 2*EKIN/BOLKEV/NDEGREES_OF_FREEDOM

! sum energy of images along chain
        
        
        
        

        ETOTAL=TOTEN+EKIN+ES+EPS

!  report  energy  of electrons + kinetic energy + nose-energy
        

        WRITE(TIU6,7260) TOTEN,EKIN,TEIN,ES,EPS,ETOTAL

        CALL XML_TAG("energy")
        CALL XML_ENERGY(TOTEN,TOTEN-E%EENTROPY/(2+NORDER),E%EENTROPY)
        CALL XML_TAG_REAL("kinetic",EKIN)
        CALL XML_TAG_REAL("nosepot",ES)
        CALL XML_TAG_REAL("nosekinetic",EPS)
        CALL XML_TAG_REAL("total",ETOTAL)
        CALL XML_CLOSE_TAG

        WRITE(17,7280,ADVANCE='NO') NSTEP,TEIN,ETOTAL,TOTEN, &
             TOTEN-E%EENTROPY/(2+NORDER),EKIN,ES,EPS
        IF (IO%IU0>=0) &
             WRITE(TIU0,7280,ADVANCE='NO')NSTEP,TEIN,ETOTAL,TOTEN, &
             TOTEN-E%EENTROPY/(2+NORDER),EKIN,ES,EPS         
        IF (WDES%NCDIJ>=2) THEN
           WRITE(17,77280) RHOTOT(2:WDES%NCDIJ)
           IF (IO%IU0>=0) WRITE(TIU0,77280) RHOTOT(2:WDES%NCDIJ)
        ELSE
           WRITE(17,*)
           IF (IO%IU0>=0) WRITE(TIU0,*)
        ENDIF

! aspherical contribution and metagga (Robin Hirschl)
        IF (INFO%LASPH) THEN
           WRITE(17,72811) NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72811)NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
        ENDIF
        IF (INFO%LMETAGGA) THEN
           WRITE(17,72812) NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72812)NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
        ENDIF
        WRITE(TIU6,7270) DISMAX
        
        

7260  FORMAT(/ &
     &        '  ENERGIE OF THE ELECTRON-ION-THERMOSTAT SYSTEM (eV)'/ &
     &        '  ---------------------------------------------------'/ &
     &        '% ion-electron   TOTEN  = ',F16.6,'  see above'/ &
     &        '  kinetic Energy EKIN   = ',F16.6, &
     &        '  (temperature',F8.2,' K)'/ &
     &        '  nose potential ES     = ',F16.6/ &
     &        '  nose kinetic   EPS    = ',F16.6/ &
     &        '  ---------------------------------------------------'/ &
     &        '  total energy   ETOTAL = ',F16.6,' eV'/)

 7270 FORMAT( '  maximum distance moved by ions :',E14.2/)

 7280 FORMAT(I4,' T= ',F6.0,' E= ',E14.8, &
     &   ' F= ',E14.8,' E0= ',E14.8,1X,' EK= ',E11.5, &
     &   ' SP= ',E8.2,' SK= ',E8.2)
77280 FORMAT(' mag=',3F11.3)

!=======================================================================
!  IBRION ==5 finite differences
!=======================================================================
      ELSE IF (DYN%IBRION==5) THEN ibrion
        EENTROPY=E%EENTROPY

        
        WRITE(17,7281,ADVANCE='NO') NSTEP,TOTEN, &
             TOTEN-EENTROPY/(2+NORDER),TOTEN-TOTENG
        IF (IO%IU0>=0) &
             WRITE(TIU0,7281,ADVANCE='NO')NSTEP,TOTEN, &
             TOTEN-EENTROPY/(2+NORDER),TOTEN-TOTENG

        IF ( WDES%NCDIJ>=2 ) THEN
           WRITE(17,77281) RHOTOT(2:WDES%NCDIJ) 
           IF (IO%IU0>=0) WRITE(TIU0,77281) RHOTOT(2:WDES%NCDIJ)
        ELSE
           WRITE(17,*)
           IF (IO%IU0>=0) WRITE(TIU0,*)
        ENDIF
        
! aspherical contribution and metagga (Robin Hirschl)
        IF (INFO%LASPH) THEN
           WRITE(17,72811) NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72811)NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
        ENDIF
        IF (INFO%LMETAGGA) THEN
           WRITE(17,72812) NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72812)NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
        ENDIF

        

        DYN%POSIOC=DYN%POSION
        CALL FINITE_DIFF( INFO%LSTOP, DYN%POTIM, T_INFO%NIONS, T_INFO%NTYP, &
             T_INFO%NITYP, T_INFO%POMASS, DYN%POSION, TIFOR, DYN%NFREE, &
             T_INFO%LSDYN,T_INFO%LSFOR, LATT_CUR%A, LATT_CUR%B,  &
             IO%IU6, IO%IU0)
        ! we need to reinitialise the symmetry code at this point
        ! at least if the user has switched it on
        ! this will obviously not regenerate the k-point grid
        IF (SYMM%ISYM>0) THEN
          CALL INISYM(LATT_CUR%A,DYN%POSION,DYN%VEL,T_INFO%LSFOR, &
             T_INFO%LSDYN,T_INFO%NTYP,T_INFO%NITYP,NIOND, &
             SYMM%PTRANS,SYMM%ROTMAP,SYMM%TAU,SYMM%TAUROT,SYMM%WRKROT, &
             SYMM%INDROT,T_INFO%ATOMOM,WDES%SAXIS,SYMM%MAGROT,NCDIJ,IO%IU6)
        ENDIF
!=======================================================================
! DYN%IBRION =
! 1  quasi-Newton algorithm
! 2  conjugate gradient
! 3  quickmin
! 4  not supported yet
! 5  finite differences
!-----------------------------------------------------------------------
! meaning of DYN%ISIF :
!  DYN%ISIF  calculate                           relax
!        force     stress                    ions      lattice
!   0     X                                   X
!   1     X        uniform                    X
!   2     X          X                        X
!   3     X          X                        X          X
!   4     X          X                        X          X **
!   5     X          X                                   X **
!   6     X          X                                   X
!   7     X          X                                  uniform
!
!   **  for DYN%ISIF=4 & DYN%ISIF=5 isotropic pressure will be subtracted
!       (-> cell volume constant, optimize only the cell shape)
!
!=======================================================================
      ELSE IF (DYN%IBRION>0) THEN ibrion
! sum energy of images along chain
        EENTROPY=E%EENTROPY

        
        

        
        WRITE(17,7281,ADVANCE='NO') NSTEP,TOTEN, &
             TOTEN-EENTROPY/(2+NORDER),TOTEN-TOTENG
        IF (IO%IU0>=0) &
             WRITE(TIU0,7281,ADVANCE='NO')NSTEP,TOTEN, &
             TOTEN-EENTROPY/(2+NORDER),TOTEN-TOTENG

        IF ( WDES%NCDIJ>=2 ) THEN
           WRITE(17,77281) RHOTOT(2:WDES%NCDIJ) 
           IF (IO%IU0>=0) WRITE(TIU0,77281) RHOTOT(2:WDES%NCDIJ)
        ELSE
           WRITE(17,*)
           IF (IO%IU0>=0) WRITE(TIU0,*)
        ENDIF

! aspherical contribution and metagga (Robin Hirschl)
        IF (INFO%LASPH) THEN
           WRITE(17,72811) NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72811)NSTEP,E%TOTENASPH, &
                E%TOTENASPH-E%EENTROPY/(2+NORDER)
        ENDIF
        IF (INFO%LMETAGGA) THEN
           WRITE(17,72812) NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
           IF (IO%IU0>=0) &
                WRITE(TIU0,72812)NSTEP,E%TOTENMGGA, &
                E%TOTENMGGA-E%EENTROPY/(2+NORDER)
        ENDIF

        
 7281 FORMAT(I4,' F= ',E14.8,' E0= ',E14.8,1X,' d E =',E12.6)
77281 FORMAT('  mag=',3F11.4)
!-----------------------------------------------------------------------
!  set DYN%D2C to forces in cartesian coordinates multiplied by FACT
!  FACT is determined from timestep in a way, that a stable timestep
!   gives a good trial step
!-----------------------------------------------------------------------
        FACT=0
        IF (DYN%ISIF<5) FACT=10*DYN%POTIM*EVTOJ/AMTOKG *1E-10_q
        LSTOP2=.TRUE.

        NI=1
        DO NT=1,T_INFO%NTYP
        DO NI=NI,T_INFO%NITYP(NT)+NI-1
           DYN%D2C(1,NI)=TIFOR(1,NI)*FACT
           DYN%D2C(2,NI)=TIFOR(2,NI)*FACT
           DYN%D2C(3,NI)=TIFOR(3,NI)*FACT
           IF (SQRT(TIFOR(1,NI)**2+TIFOR(2,NI)**2+TIFOR(3,NI)**2) &
                &       >ABS(DYN%EDIFFG)) LSTOP2=.FALSE.
        ENDDO
        ENDDO
! for all DYN%ISIF greater or equal 3 cell shape optimisations will be done
        FACTSI = 0
        IF (DYN%ISIF>=3) FACTSI=10*DYN%POTIM*EVTOJ/AMTOKG/T_INFO%NIONS *1E-10_q

        DO I=1,3
        DO K=1,3
           D2SIF(I,K)=TSIF(I,K)*FACTSI
        ENDDO
        D2SIF(I,I)=D2SIF(I,I)-DYN%PSTRESS/(EVTOJ*1E22_q)*LATT_CUR%OMEGA*FACTSI
        ENDDO
! For DYN%ISIF =4 or =5 we take only pure shear stresses: subtract pressure
        IF ((DYN%ISIF==4).OR.(DYN%ISIF==5)) THEN
           DO I=1,3
              D2SIF(I,I)=D2SIF(I,I)-PRESS*FACTSI
           ENDDO
        ENDIF
! For DYN%ISIF =7 take only pressure (volume relaxation)
        IF (DYN%ISIF==7) THEN
           DO I=1,3
           DO J=1,3
              D2SIF(J,I)=0
           ENDDO
           D2SIF(I,I)=PRESS*FACTSI
           ENDDO
        ENDIF

        CALL CONSTR_CELL_RELAX(D2SIF)

        IF (FACTSI/=0) THEN
           DO I=1,3
           DO J=1,3
              IF (FACTSI/=0) THEN
                 IF (ABS(D2SIF(J,I))/FACTSI/T_INFO%NIONS>ABS(DYN%EDIFFG)) LSTOP2=.FALSE.
              ENDIF
           ENDDO
          ENDDO
        ENDIF
!-----------------------------------------------------------------------
!  do relaxations using diverse algorithms
!-----------------------------------------------------------------------
        ! change of the energy between two ionic step used as stopping criterion
        INFO%LSTOP=(ABS(TOTEN-TOTENG)<DYN%EDIFFG)
        
        
        

        ! IFLAG=0 means no reinit of wavefunction prediction
        IFLAG=0
        IF (DYN%IBRION==1) THEN
           CALL BRIONS(T_INFO%NIONS,DYN%POSION,DYN%POSIOC,DYN%D2C,LATT_CUR%A,LATT_CUR%B,D2SIF, &
                MAX(DYN%NSW+1,DYN%NFREE+1),DYN%NFREE,IO%IU6,IO%IU0,FACT,FACTSI,E1TEST)
! Sometimes there is the danger that the optimisation scheme (especially
! the Broyden scheme) fools itself by performing a 'too small' step - to
! avoid this use a second break condition ('trial step energy change'):
           INFO%LSTOP=INFO%LSTOP .AND. (ABS(E1TEST) < DYN%EDIFFG)
! if we have very small forces (small trial energy change) we can stop
           INFO%LSTOP=INFO%LSTOP .OR. (ABS(E1TEST) < 0.1_q*DYN%EDIFFG)
           TOTENG=TOTEN
!-----------------------------------------------------------------------
        ELSE IF (DYN%IBRION==3 .AND. DYN%SMASS<=0) THEN
           CALL ION_VEL_QUENCH(T_INFO%NIONS,LATT_CUR%A,LATT_CUR%B,IO%IU6,IO%IU0, &
                T_INFO%LSDYN, &
                DYN%POSION,DYN%POSIOC,FACT,DYN%D2C,FACTSI,D2SIF,DYN%D2,E1TEST)
           IF (IFLAG==1) INFO%LSTOP=INFO%LSTOP .OR. (ABS(E1TEST) < 0.1_q*DYN%EDIFFG)
!-----------------------------------------------------------------------
        ELSE IF (DYN%IBRION==3) THEN
           CALL IONDAMPED(T_INFO%NIONS,LATT_CUR%A,LATT_CUR%B,IO%IU6,IO%IU0, &
                T_INFO%LSDYN, &
                DYN%POSION,DYN%POSIOC,FACT,DYN%D2C,FACTSI,D2SIF,DYN%D2,E1TEST,DYN%SMASS)
           IF (IFLAG==1) INFO%LSTOP=INFO%LSTOP .OR. (ABS(E1TEST) < 0.1_q*DYN%EDIFFG)
!-----------------------------------------------------------------------
        ELSE IF (DYN%IBRION==2) THEN
           IFLAG=1
           IF (NSTEP==1) IFLAG=0
!  set accuracy of energy (determines whether cubic interpolation is used)
           EACC=MAX(ABS(INFO%EDIFF),ABS(DESUM(NELMLS)))

           
           IF ( LHYPER_NUDGE() ) EACC=1E10    ! energy not very accurate, use only force

           CALL IONCGR(IFLAG,T_INFO%NIONS,TOTEN,LATT_CUR%A,LATT_CUR%B,DYN%NFREE,DYN%POSION,DYN%POSIOC, &
                FACT,DYN%D2C,FACTSI,D2SIF,DYN%D2,DYN%D3,DISMAX,IO%IU6,IO%IU0, &
                EACC,DYN%EDIFFG,E1TEST,LSTOP2)
!    if IFLAG=1 new trial step -> reinit of waveprediction
           INFO%LSTOP=.FALSE.
           IF (IFLAG==1) THEN
              INFO%LSTOP=(ABS(TOTEN-TOTENG)<DYN%EDIFFG)
              TOTENG=TOTEN
           ENDIF
           IF (IFLAG==2) INFO%LSTOP=.TRUE.
! if we have very small forces (small trial energy change) we can stop
           IF (IFLAG==1) INFO%LSTOP=INFO%LSTOP .OR. (ABS(E1TEST) < 0.1_q*DYN%EDIFFG)
!-----------------------------------------------------------------------
        ENDIF

! restrict volume for constant volume relaxation
        IF (DYN%ISIF==4 .OR. DYN%ISIF==5) THEN
           OMEGA_OLD=LATT_CUR%OMEGA
           CALL LATTIC(LATT_CUR)
           SCALEQ=(ABS(OMEGA_OLD) / ABS(LATT_CUR%OMEGA))**(1._q/3._q)
           DO I=1,3
              LATT_CUR%A(1,I)=SCALEQ*LATT_CUR%A(1,I)
              LATT_CUR%A(2,I)=SCALEQ*LATT_CUR%A(2,I)
              LATT_CUR%A(3,I)=SCALEQ*LATT_CUR%A(3,I)
           ENDDO
        ENDIF
        CALL LATTIC(LATT_CUR)
!  reinitialize the prediction algorithm for the wavefunction if needed
        PRED%INIPRE=3
        IF ( PRED%IWAVPR >=12 .AND. &
             &     (ABS(TOTEN-TOTENG)/T_INFO%NIONS>1.0_q .OR. IFLAG==1)) THEN
           CALL WAVPRE_NOIO(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
                CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)

        ELSE IF ( PRED%IWAVPR >=2 .AND. PRED%IWAVPR <10   .AND. &
             &     (ABS(TOTEN-TOTENG)/T_INFO%NIONS>1.0_q .OR. IFLAG==1)) THEN
           CALL WAVPRE(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
                CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)
        ENDIF

        ! use forces as stopping criterion if EDIFFG<0
        IF (DYN%EDIFFG<0) INFO%LSTOP=LSTOP2
        
        WRITE(TIU6,130)

        IF (INFO%LSTOP) THEN
           IF (IO%IU0>=0) &
                WRITE(TIU0,*) 'reached required accuracy - stopping ', &
                'structural energy minimisation'
           WRITE(TIU6,*) ' '
           WRITE(TIU6,*) 'reached required accuracy - stopping ', &
                'structural energy minimisation'
        ENDIF
        
      ENDIF ibrion
!=======================================================================
!  update of ionic positions performed
!  in any case POSION should now hold the new positions and
!  POSIOC the old (1._q,0._q)
!=======================================================================


!-----reached required number of time steps
      IF (NSTEP>=DYN%NSW) INFO%LSTOP=.TRUE.
!-----soft stop or hard stop
      IF (INFO%LSOFT) INFO%LSTOP=.TRUE.

!     if we need to pull the brake, then POSION is reset to POSIOC
!     except for molecular dynamics, where the next electronic
!     step should indeed correspond to POSIOC 
      IF ( INFO%LSTOP .AND. DYN%IBRION/=0 ) THEN
         LATT_CUR%A=DYN%AC
         CALL LATTIC(LATT_CUR)
         DYN%POSION=DYN%POSIOC
      ENDIF

      

!=======================================================================
!  update mean temperature mean energy
!=======================================================================
      SMEAN =SMEAN +1._q/DYN%SNOSE(1)
      SMEAN0=SMEAN0+DYN%SNOSE(1)
      TMEAN =TMEAN +TEIN/DYN%SNOSE(1)
      TMEAN0=TMEAN0+TEIN
!=======================================================================
!  SMEAR_LOOP%ISMCNT != 0 Loop over several KPOINTS%SIGMA-values
!  set new smearing parameters and continue main loop
!=======================================================================
      IF (SMEAR_LOOP%ISMCNT/=0) THEN
      KPOINTS%ISMEAR=NINT(SMEAR_LOOP%SMEARS(2*SMEAR_LOOP%ISMCNT-1))
      KPOINTS%SIGMA=SMEAR_LOOP%SMEARS(2*SMEAR_LOOP%ISMCNT)

      SMEAR_LOOP%ISMCNT=SMEAR_LOOP%ISMCNT-1

      
      IF (IO%IU0>=0) &
      WRITE(TIU0,7283) KPOINTS%ISMEAR,KPOINTS%SIGMA
      WRITE(17,7283) KPOINTS%ISMEAR,KPOINTS%SIGMA
      

 7283 FORMAT('ISMEAR = ',I4,' SIGMA = ',F10.3)

      KPOINTS%LTET=((KPOINTS%ISMEAR<=-4).OR.(KPOINTS%ISMEAR>=30))
      IF (KPOINTS%ISMEAR==-6) KPOINTS%ISMEAR=-1
      IF (KPOINTS%ISMEAR>=0)  KPOINTS%ISMEAR=MOD(KPOINTS%ISMEAR,30)
      SIGMA=ABS(KPOINTS%SIGMA)

      CALL DENSTA( IO%IU0, IO%IU6, WDES, W, KPOINTS, INFO%NELECT, &
               INFO%NUP_DOWN, E%EENTROPY, EFERMI, SIGMA, &
               NEDOS, 0, 0, DOS, DOSI, PAR, DOSPAR)

      ENDIF
!=======================================================================
! tasks which are done all DYN%NBLOCK   steps:
!=======================================================================
!-----------------------------------------------------------------------
!  write out the position of the IONS to XDATCAR
!-----------------------------------------------------------------------
      IF (INFO%INICHG==3) THEN
        IF (MOD(NSTEP,DYN%NBLOCK)==1) THEN
           IF (IO%IU0>=0) &
           WRITE(TIU0,*) 'non selfconsistent'
           INFO%LCHCON=.FALSE.
        ELSE
           IF (IO%IU0>=0) &
           WRITE(TIU0,*) 'selfconsistent'
           INFO%LCHCON=.TRUE.
        ENDIF
      ENDIF

   nblock: IF (MOD(NSTEP,DYN%NBLOCK)==0) THEN
        
        IF (MOD(NSTEP,DYN%NBLOCK*DYN%KBLOCK)==0) THEN
          WRITE(61,*) 'Konfig=',NSTEP
        ELSE
          WRITE(61,*)
        ENDIF
        WRITE(61,7007) ((DYN%POSIOC(I,J),I=1,3),J=1,T_INFO%NIONS)
        IF (IO%LOPEN) CALL WFORCE(61)
        
!-----------------------------------------------------------------------
! acummulate dos
!-----------------------------------------------------------------------
        DO ISP=1,WDES%NCDIJ
        DO I=1,NEDOS
          DDOSI(I,ISP)=DDOSI(I,ISP)+DOSI(I,ISP)
          DDOS (I,ISP)=DDOS (I,ISP)+DOS (I,ISP)
        ENDDO
        ENDDO
!-----------------------------------------------------------------------
! evaluate the pair-correlation function  using the exact places
! also sum up mean temperatur
!-----------------------------------------------------------------------
        SMEANP =SMEANP +1._q
        CALL SPACO(T_INFO%NIONS,1._q,DYN%POSIOC,DYN%AC,LATT_CUR%BNORM,PACO%SIPACO(0),PACO%NPACO,PACO%APACO)
      ENDIF nblock

!=======================================================================
! tasks which are done all DYN%NBLOCK*DYN%KBLOCK   steps
!=======================================================================
!-----------------------------------------------------------------------
! write  pair-correlation and density of states
! quantities are initialized to 0 at the beginning of the main-loop
!-----------------------------------------------------------------------
    wrtpair: IF (MOD(NSTEP,DYN%NBLOCK*DYN%KBLOCK)==0) THEN
      

      PCFAK = 1.5_q/PI/T_INFO%NIONS**2*LATT_CUR%OMEGA*(PACO%NPACO/PACO%APACO)**3
      WRITE(60,'(3E15.7)') TMEAN0/(DYN%NBLOCK*DYN%KBLOCK),TMEAN/SMEAN
      WRITE(TIU6,8022) SMEAN0/(DYN%NBLOCK*DYN%KBLOCK),TMEAN0/(DYN%NBLOCK*DYN%KBLOCK), &
     &                TMEAN/SMEAN
 8022 FORMAT(/' mean value of Nose-termostat <S>:',F10.3, &
     &        ' mean value of <T> :',F10.3/ &
     &        ' mean temperature <T/S>/<1/S>  :',F10.3/)

      DO  I=0,PACO%NPACO-1
         WRITE(60,'(F7.3)') &
          PCFAK*PACO%SIPACO(I)/ REAL( 3*I*(I+1)+1 ,KIND=q) /SMEANP
      ENDDO

      IF (IO%LOPEN) CALL WFORCE(60)
      WRITE(16,'(2F16.8,I5,2F16.8)') KPOINTS%EMAX,KPOINTS%EMIN,NEDOS,EFERMI,1.0
      DELTAE=(KPOINTS%EMAX-KPOINTS%EMIN)/(NEDOS-1)
      DO I=1,NEDOS
        EN=KPOINTS%EMIN+DELTAE*(I-1)
        WRITE(16,7062) EN,(DDOS(I,ISP)/DYN%KBLOCK,ISP=1,WDES%ISPIN),(DDOSI(I,ISP)/DYN%KBLOCK,ISP=1,WDES%ISPIN)
      ENDDO
      IF (IO%LOPEN) CALL WFORCE(16)
 7062 FORMAT(3X,F8.3,8E12.4)

      
    ENDIF wrtpair
!-----------------------------------------------------------------------
!  update file CONTCAR
!-----------------------------------------------------------------------

!-----write out positions (only done on IONODE)

     

      CALL OUTPOS(13,.TRUE.,T_INFO%SZNAM2,LATT_CUR%SCALE,DYN%AC,T_INFO%NTYP,T_INFO%NITYP,T_INFO%LSDYN, &
     &                  T_INFO%NIONS,DYN%POSIOC,T_INFO%LSFOR )
      CALL OUTPOS_TRAIL(13,IO%LOPEN, LATT_CUR, T_INFO, DYN)

     
!=======================================================================
!  append new chargedensity to file CHG
!=======================================================================
      IF (IO%LCHARG .AND. MOD(NSTEP,10)==1) THEN

      
      CALL OUTPOS(70,.FALSE.,INFO%SZNAM1,LATT_CUR%SCALE,LATT_CUR%A,T_INFO%NTYP,T_INFO%NITYP,.FALSE., &
     &                  T_INFO%NIONS,DYN%POSIOC,T_INFO%LSFOR)
      

      DO ISP=1,WDES%NCDIJ
         CALL OUTCHG(GRIDC,70,.FALSE.,CHTOT(1,ISP))
      ENDDO
      
      IF (IO%LOPEN) CALL WFORCE(70)
      
      ENDIF
!=======================================================================
! if ions were moved recalculate some quantities
!=======================================================================
!=======================================================================
! WAVPRE prediction of the new wavefunctions and charge-density
! if charge-density constant during ELM recalculate the charge-density
! according to overlapping atoms
! for relaxation jobs do not predict in the last step
!=======================================================================
      INFO%LPOTOK=.FALSE.
  prepare_next_step: &
    & IF ( .NOT. INFO%LSTOP .OR. DYN%IBRION==0 ) THEN
      CALL VTIME(TV0,TC0)

      ! extrapolate charge using  atomic charges
      IF (PRED%IWAVPR==1 .OR.PRED%IWAVPR==11) PRED%INIPRE=5
      ! extrapolate wavefunctions and charge
      IF (PRED%IWAVPR==2 .OR.PRED%IWAVPR==12) PRED%INIPRE=0
      ! mixed mode
      IF (PRED%IWAVPR==3 .OR.PRED%IWAVPR==13) PRED%INIPRE=4
      PRED%IPRE=0

      IF (PRED%IWAVPR >=11) THEN
        CALL WAVPRE_NOIO(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
           CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)
      ELSE IF (PRED%IWAVPR >=1 .AND. PRED%IWAVPR<10 ) THEN
        CALL WAVPRE(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
           CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)
      ENDIF

      IF (PRED%IPRE<0) THEN
        
        IF (IO%IU0>=0) &
        WRITE(TIU0,*)'bond charge predicted'
        
        PRED%IPRE=ABS(PRED%IPRE)
      ELSE
      ! PRED%IPRE < 0 then WAVPRE calculated new structure factor
      !     in all other cases we have to recalculate s.f.
        CALL STUFAK(GRIDC,T_INFO,CSTRF)
      ENDIF

      IF (INFO%LCHCON.AND.INFO%INICHG==2) THEN
        IF (IO%IU0>=0)  WRITE(TIU0,*)'charge from overlapping atoms'
        CALL RHOATO_WORK(.FALSE.,.FALSE.,GRIDC,T_INFO,LATT_CUR%B,P,CSTRF,CHTOT)
        ! set magnetization to 0
        DO ISP=2,WDES%NCDIJ
           CALL RC_ADD(CHTOT(1,ISP),0.0_q,CHTOT(1,ISP),0.0_q,CHTOT(1,ISP),GRIDC)
        ENDDO
      ENDIF

      IF (INFO%LCORE) CALL RHOPAR(GRIDC,T_INFO,LATT_CUR%B,P,CSTRF,DENCOR)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'WAVPRE',TV-TV0,TC-TC0
!-----------------------------------------------------------------------
! call the ewald program to get the energy of the new ionic
! configuration
!-----------------------------------------------------------------------
      CALL VTIME(TV0,TC0)
      CALL FEWALD(DYN%POSION,EWIFOR,LATT_CUR%A,LATT_CUR%B,LATT_CUR%ANORM,LATT_CUR%BNORM, &
     &     LATT_CUR%OMEGA,EWSIF,E%TEWEN,T_INFO%NTYP,P%ZVALF,T_INFO%NIONS,NIOND,T_INFO%ITYP,T_INFO%NITYP,IO%IU6)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'FEWALD',TV-TV0,TC-TC0

! volume might have changed restet IRDMAX
      IRDMAX=4*PI*PSDMX**3/3/(LATT_CUR%OMEGA/ &
     &     (GRIDC%NGPTAR(1)*GRIDC%NGPTAR(2)*GRIDC%NGPTAR(3)))+200
       IRDMAX=4*PI*PSDMX**3/3/(LATT_CUR%OMEGA/ &
     &        (GRIDUS%NGPTAR(1)*GRIDUS%NGPTAR(2)*GRIDUS%NGPTAR(3)))+200
!-----------------------------------------------------------------------
! if basis cell changed recalculate kinetic-energy array and tables
!-----------------------------------------------------------------------
      IF (DYN%ISIF>=3) THEN
        CALL VTIME(TV0,TC0)
        CALL GEN_INDEX(GRID,WDES, LATT_CUR%B,LATT_INI%B,-1,-1,.TRUE.)
        CALL VTIME(TV,TC)
        IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'GENKIN',TV-TV0,TC-TC0
      ENDIF
!-----------------------------------------------------------------------
!  recalculate the real-space projection operatores
!  if volume changed also recalculate reciprocal projection operatores
!  and reset the cache for the phase-factor
!-----------------------------------------------------------------------
      IF (INFO%LREAL) THEN
! reset IRMAX, IRALLOC if required (no redistribution of GRIDS allowed)

        CALL REAL_OPTLAY(GRID,LATT_CUR,NONLR_S,.TRUE.,LREALLOCATE, IO%IU6,IO%IU0)
        IF (LREALLOCATE) THEN
           ! reallocate real space projectors
           CALL NONLR_DEALLOC(NONLR_S)
           CALL NONLR_ALLOC(NONLR_S)
        END IF
        CALL RSPHER(GRID,NONLR_S,LATT_CUR)

      ELSE
        IF (DYN%ISIF>=3) THEN
          IZERO=1
          CALL SPHER(GRID,NONL_S,P,WDES,LATT_CUR,  IZERO,LATT_INI%B)
        ENDIF
        CALL PHASE(WDES,NONL_S,0)
      ENDIF
!-----------------------------------------------------------------------
! recalculate projections and performe gram-schmidt orthogonalisation
!-----------------------------------------------------------------------
      CALL WVREAL(WDES,GRID,W) ! only for gamma some action
      CALL VTIME(TV0,TC0)
      CALL PROALL (GRID,LATT_CUR,NONLR_S,NONL_S,WDES,W, &
           INFO%LOVERL,INFO%LREAL,LMDIM)
      CALL ORTHCH(WDES,W, INFO%LOVERL, LMDIM,CQIJ,NBLK)
      CALL REDIS_PW_ALL(WDES, W)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'ORTHCH',TV-TV0,TC-TC0
!-----------------------------------------------------------------------
! set  INFO%LPOTOK to .F. this requires a recalculation of the local pot.
!-----------------------------------------------------------------------
      INFO%LPOTOK=.FALSE.
!-----------------------------------------------------------------------
! if prediction of wavefuntions was performed and
! diagonalisation of sub-space-matrix is selected then
! )  POTLOK: calculate potential according to predicted charge-density
! )  SETDIJ: recalculate the energy of the augmentation charges
! )  then performe a sub-space-diagonal. and generate new fermi-weights
! )  set INFO%LPOTOK to true because potential is OK
! )  recalculate total energy
! if charge density not constant during band minimisation
! )  calculate charge-density according to new wavefunctions
!     and set LPOTOK to false (requires recalculation of loc. potential)
! in all other cases the predicted chargedensity is used in the next
!   step of ELM
!-----------------------------------------------------------------------
  pre_done: IF (PRED%IPRE>1) THEN
      
      IF (IO%IU0>=0) &
      WRITE(TIU0,*)'prediction of wavefunctions'

      WRITE(TIU6,2450) PRED%ALPHA,PRED%BETA
      
 2450 FORMAT(' Prediction of Wavefunctions ALPHA=',F6.3,' BETA=',F6.3)

!   wavefunctions are not diagonal, so if they are written to the file
!   or if we do not diagonalize before the optimization
!   rotate them now
  pre_subrot: IF (.NOT.INFO%LDIAG .OR. INFO%LONESW .OR. &
     &     INFO%LSTOP .OR. (MOD(NSTEP,10)==0 &
     &     .AND. PRED%IWAVPR >= 2 .AND.  PRED%IWAVPR < 10) ) THEN

      CALL VTIME(TV0,TC0)
      IF (IO%IU0>=0) &
      WRITE(TIU0,*)'wavefunctions rotated'
      CALL POTLOK(GRID,GRIDC,GRID_SOFT, WDES%COMM_INTER, WDES, &
                  EXCTAB,INFO,P,T_INFO,E,LATT_CUR,DIP, &
                  CHTOT,CSTRF,CVTOT,DENCOR,SV, SOFT_TO_C,XCSIF)

      CALL SETDIJ(WDES,GRIDC,GRIDUS,C_TO_US,LATT_CUR,P,T_INFO,INFO%LOVERL, &
                  LMDIM,CDIJ,CQIJ,CVTOT,IRDMAA,IRDMAX,.0_q,.0_q,.0_q)

      CALL SET_DD_PAW(WDES, P , T_INFO, INFO%LOVERL, &
         WDES%NCDIJ, LMDIM, CDIJ,  RHOLM, CRHODE, INFO%LEXCH, INFO%LEXCHG, &
          E, LMETA =  .FALSE., LASPH =.FALSE. , LCOREL=.FALSE.)

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0) WRITE(TIU6,2300)'POTLOK',TV-TV0,TC-TC0
      INFO%LPOTOK=.TRUE.
      CALL VTIME(TV0,TC0)

      IFLAG=3
      CALL EDDIAG(GRID,GRID,LATT_CUR,NONLR_S,NONL_S,W,WDES, &
          LMDIM,CDIJ,CQIJ, IFLAG,INFO%LOVERL,INFO%LREAL,NBLK,SV,IO%IU0, &
          E%EXHF,.FALSE.)
      CALL REDIS_PW_ALL(WDES, W)

      SIGMA=ABS(KPOINTS%SIGMA)
      CALL DENSTA( IO%IU0, IO%IU6, WDES, W, KPOINTS, &
               INFO%NELECT, INFO%NUP_DOWN, E%EENTROPY, EFERMI, SIGMA, &
               NEDOS, 0, 0, DOS, DOSI, PAR, DOSPAR)
      CALL DEPSUM(W,WDES, LMDIM,CRHODE, INFO%LOVERL)
      CALL US_FLIP(WDES, LMDIM, CRHODE, INFO%LOVERL, .FALSE.)
     ! for the selfconsistent update set TOTEN now

      IF (INFO%LONESW) THEN
        DO ISP=1,WDES%ISPIN
        DO NK=1,KPOINTS%NKPTS
        DO K=1,WDES%NB_TOT
            W_F%CELTOT(K,NK)=W%CELTOT(K,NK,ISP)
        ENDDO ; ENDDO ; ENDDO
      ENDIF

      E%EBANDSTR=0.0_q

      DO ISP=1,WDES%ISPIN
      DO I=1,KPOINTS%NKPTS
      DO II=1,WDES%NB_TOT
        E%EBANDSTR=E%EBANDSTR+WDES%RSPIN* REAL( W%CELTOT(II,I,ISP) ,KIND=q) *KPOINTS%WTKPT(I)*W%FERTOT(II,I,ISP)
      ENDDO; ENDDO; ENDDO

      TOTEN=E%EBANDSTR+E%DENC+E%XCENC+E%TEWEN+E%PSCENC+E%EENTROPY

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0)WRITE(TIU6,2300)'EDDIAG',TV-TV0,TC-TC0

  ENDIF pre_subrot

  ENDIF pre_done

    IF (INFO%LONESW) THEN

      CALL VTIME(TV0,TC0)

      CALL SET_CHARGE(W, WUP, WDW, WDES, INFO%LOVERL, &
           GRID, GRIDC, GRID_SOFT, GRIDUS, C_TO_US, SOFT_TO_C, &
           LATT_CUR, P, SYMM, T_INFO, &
           CHDEN, LMDIM, CRHODE, CHTOT, RHOLM, N_MIX_PAW, IRDMAX)
      INFO%LPOTOK=.FALSE.

      CALL VTIME(TV,TC)
      IF (IO%NWRITE>=2.AND.IO%IU6>=0)WRITE(TIU6,2300)'CHARGE',TV-TV0,TC-TC0

    ENDIF

  ELSE prepare_next_step
! in any case we have to call RSPHER at this point even if the ions do not move
! since the force routine overwrites the required arrays
      IF (INFO%LREAL) THEN
         CALL RSPHER(GRID,NONLR_S,LATT_CUR)
      ENDIF
  ENDIF prepare_next_step
!=======================================================================
!  update file WAVECAR if INFO%LSTOP = .TRUE.
!  or if wavefunctions on file TMPCAR are rotated
!=======================================================================
! after 10 steps rotate the wavefunctions on the file
      LTMP= MOD(NSTEP,10) == 0 .AND. PRED%IWAVPR >= 2 .AND. PRED%IWAVPR < 10

  wrtwave: IF ( IO%LWAVE .AND. (INFO%LSTOP .OR. LTMP) ) THEN
      IF(IO%IU6>=0)  WRITE(TIU6,*)'writing wavefunctions'
! write record length and ispin on record (1._q,0._q) (needed for reopening/reading)
      CALL OUTWAV(IRECLW,WDES,W,LATT_INI, IO%IU0)
      
      IF (IO%LOPEN) THEN
        CLOSE(12)         ! close and reopen (this also flushes any buffers)
        OPEN(UNIT=12,FILE=DIR_APP(1:DIR_LEN)//'WAVECAR',ACCESS='DIRECT', &
                     FORM='UNFORMATTED',STATUS='UNKNOWN',RECL=IRECLW)
      ENDIF
      
!-----------------------------------------------------------------------
! rotate wavefunctions on file (gives a better prediction)
!------------------------------------------------------------------------
      IF (LTMP) THEN
        PRED%INIPRE=10

        CALL WAVPRE(GRIDC,P,PRED,T_INFO,W,WDES,LATT_CUR,IO%LOPEN, &
           CHTOT,RHOLM,N_MIX_PAW, CSTRF, LMDIM,CQIJ,INFO%LOVERL,NBLK,IO%IU0)

        IF (IO%IU0>=0) &
             WRITE(TIU0,*)'wavefunctions on file TMPCAR rotated'
! and read in wavefunctions  (destroyed by WAVPRE)
        CALL INWAV_FAST(WDES, W, GRID, LATT_CUR, LATT_INI, ISTART, IO%IU0)

        CALL PROALL (GRID,LATT_CUR,NONLR_S,NONL_S,WDES,W, &
             INFO%LOVERL,INFO%LREAL,LMDIM)
        CALL ORTHCH(WDES,W, INFO%LOVERL, LMDIM,CQIJ,NBLK)
        CALL REDIS_PW_ALL(WDES, W)
      ENDIF

   ENDIF wrtwave
!=======================================================================
! next electronic energy minimisation
      CALL VTIME(TVPUL,TCPUL)
      IF(IO%IU6>=0)  WRITE(TIU6,2300)'LOOP+',TVPUL-TVPUL0,TCPUL-TCPUL0
      TVPUL0=TVPUL
      TCPUL0=TCPUL

      IF (.NOT. INFO%LSTOP )  CALL XML_CLOSE_TAG  ! close the calcula

      ENDDO ion
!=======================================================================

!=======================================================================
! set up the Hartree-Fock part
!=======================================================================
!      GRIDHF%NGPTAR=GRID%NGPTAR
!      GRIDHF%COMM  =>COMM_INB
!      CALL INILGRD(NGX,NGY,NGZ,GRIDHF)
!#ifdef gammareal
! gamma-point only the exchange potential is real
!      CALL GEN_RC_GRID(GRIDHF) 
!#else
! general case the exchange potential is complex
!      CALL GEN_GRID(GRIDHF) 
!#endif
! allign GRIDHF with GRID in real space
!      CALL SET_RL_GRID(GRIDHF,GRID)
!      CALL SETUP_FOCK(T_INFO, P, WDES, GRIDHF, LATT_CUR, LMDIM,  IO%IU6, IO%IU0 )
!#ifdef MPI
!      CALL MAPSET(GRIDHF)
!#endif
!
!      CALL RSPHER(GRID, FAST_AUG, LATT_CUR)
!      FAST_AUG%RPROJ= FAST_AUG%RPROJ*SQRT(LATT_CUR%OMEGA)
!      
!      CALL FOCK_TEST(GRID, GRIDHF, GRID_SOFT, W, WDES, INFO%LOVERL, CHDEN )
!      CALL FOCK_TEST2(GRID, GRIDHF, SV,  WDES, INFO%LOVERL)

!=======================================================================
! here we are at the end of the required number of timesteps
!=======================================================================
      
      IF (IO%LOPEN) CALL WFORCE(IO%IU6)
      
!=======================================================================
!  write out some additional information
!  create the File CHGCAR
!=======================================================================
      IF (IO%LCHARG) THEN
         
         REWIND 18
         ! since t
         CALL OUTPOS(18,.FALSE.,INFO%SZNAM1,LATT_CUR%SCALE,LATT_CUR%A,T_INFO%NTYP,T_INFO%NITYP,.FALSE., &
     &                  T_INFO%NIONS,DYN%POSION,T_INFO%LSFOR)
         
! if you uncomment the following lines the pseudo core charge density
! is added to the pseudo charge density         
!         CALL FFT3RC(CHTOT(1,1),GRIDC,1)
!         CALL RL_ADD(CHTOT(1,1),1._q/GRIDC%NPLWV,DENCOR(1),1._q/GRIDC%NPLWV,CHTOT(1,1),GRIDC)
!         CALL FFT3RC(CHTOT(1,1),GRIDC,-1)

         CALL OUTCHG(GRIDC,18,.TRUE.,CHTOT)
         CALL WRT_RHO_PAW(P, T_INFO, INFO%LOVERL, RHOLM(:,1), GRIDC%COMM, 18 )
         DO ISP=2,WDES%NCDIJ
             WRITE(18,'(5E20.12)') (T_INFO%ATOMOM(NI),NI=1,T_INFO%NIONS)
            CALL OUTCHG(GRIDC,18,.TRUE.,CHTOT(1,ISP))
            CALL WRT_RHO_PAW(P, T_INFO, INFO%LOVERL, RHOLM(:,ISP), GRIDC%COMM, 18 )
         ENDDO
         IF (IO%LOPEN) THEN
             CALL REOPEN(18)
         ELSE
             REWIND 18
         ENDIF
      ENDIF
!-----if we are interested in the total (local) potential write it here:
      IF (IO%LVTOT) THEN
         
         IF (IO%LOPEN) OPEN(IO%IUVTOT,FILE='LOCPOT',STATUS='UNKNOWN')
         REWIND IO%IUVTOT
         CALL OUTPOS(IO%IUVTOT,.FALSE.,INFO%SZNAM1,LATT_CUR%SCALE,LATT_CUR%A,T_INFO%NTYP,T_INFO%NITYP,.FALSE., &
     &                  T_INFO%NIONS,DYN%POSION,T_INFO%LSFOR)
         
! comment out the following line to add  exchange correlation
         INFO%LEXCHG=-1
         CALL POTLOK(GRID,GRIDC,GRID_SOFT, WDES%COMM_INTER, WDES, &
                  EXCTAB,INFO,P,T_INFO,E,LATT_CUR,DIP, &
                  CHTOT,CSTRF,CVTOT,DENCOR,SV, SOFT_TO_C,XCSIF)

         ! call the dipol routine without changing the potential
         IF ( DIP%IDIPCO >0 ) THEN
           DIP%LCOR_DIP=.FALSE.
           CALL CDIPOL_CHTOT_REC(GRIDC, LATT_CUR,P,T_INFO, DIP, &
               CHTOT,CSTRF,CVTOT, WDES%NCDIJ, INFO%NELECT, E%PSCENC )

           CALL WRITE_VACUUM_LEVEL(IO%IU6, DIP)
         ENDIF

         CALL OUTPOT(GRIDC, IO%IUVTOT,.TRUE.,CVTOT)
         DO ISP=2,WDES%NCDIJ
            TIUVTOT = IO%IUVTOT
             WRITE(TIUVTOT,'(5E20.12)') (T_INFO%ATOMOM(NI),NI=1,T_INFO%NIONS)
            CALL OUTPOT(GRIDC, IO%IUVTOT,.TRUE.,CVTOT(1,ISP))
         ENDDO
         IF (IO%LOPEN) THEN
             CALL REOPEN(IO%IUVTOT)
         ELSE
             REWIND IO%IUVTOT
         ENDIF
      ENDIF
!=======================================================================
!  Write out the Eigenvalues
!=======================================================================
      
      DO NK=1,KPOINTS%NKPTS
        WRITE(22,*)
        WRITE(22,'(4E15.7)') WDES%VKPT(1,NK),WDES%VKPT(2,NK),WDES%VKPT(3,NK),KPOINTS%WTKPT(NK)
        DO N=1,WDES%NB_TOT
          IF (INFO%ISPIN==1) WRITE(22,852) N,REAL( W%CELTOT(N,NK,1) ,KIND=q)
          IF (INFO%ISPIN==2) &
            WRITE(22,8852) N,REAL( W%CELTOT(N,NK,1) ,KIND=q) ,REAL( W%CELTOT(N,NK,INFO%ISPIN) ,KIND=q)
        ENDDO
      ENDDO
      IF (IO%LOPEN) CALL WFORCE(22)
      
      CALL XML_EIGENVALUES(W%CELTOT,W%FERTOT, WDES%NB_TOT, KPOINTS%NKPTS, INFO%ISPIN)

  852 FORMAT(1X,I3,4X,F10.4)
 8852 FORMAT(1X,I3,4X,F10.4,2X,F10.4)
!=======================================================================
!  calculate optical matrix elements
!=======================================================================
      IF (IO%LOPTICS) THEN
        CALL VTIME(TV0,TC0)
        IF (NPAR /=1) THEN
           CALL VTUTOR('W','nooptics',RTUT,1, &
     &          ITUT,1,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
           CALL VTUTOR('W','nooptics',RTUT,1, &
     &          ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
        ELSE
           ALLOCATE(NABIJ(WDES%NB_TOT,WDES%NB_TOT))

           CALL CALC_NABIJ(NABIJ,W,WDES,P,KPOINTS,GRID_SOFT,LATT_CUR, &
             IO,INFO,T_INFO,NBLK,COMM,IU0,55)
           DEALLOCATE(NABIJ)
           CALL VTIME(TV,TC)
           IF(IO%IU6>=0)  WRITE(TIU6,2300)'NABIJ',TV-TV0,TC-TC0
        ENDIF
      ENDIF
!=======================================================================
!  calculate ELF
!=======================================================================
      IF (IO%LELF) THEN
      ALLOCATE(CWORK(GRID_SOFT%MPLWV,WDES%NCDIJ))

      CALL ELF(GRID,GRID_SOFT,LATT_CUR,SYMM,NIOND, W,WDES,  &
               CHDEN,CWORK)
! write ELF to file ELFCAR
      
      OPEN(UNIT=53,FILE='ELFCAR',STATUS='UNKNOWN')
      CALL OUTPOS(53,.FALSE.,INFO%SZNAM1,LATT_CUR%SCALE,LATT_CUR%A,T_INFO%NTYP,T_INFO%NITYP,.FALSE., &
     &                  T_INFO%NIONS,DYN%POSION,T_INFO%LSFOR)
      

      DO ISP=1,WDES%NCDIJ
         CALL OUTCHG(GRID_SOFT,53,.FALSE.,CWORK(1,ISP))
      ENDDO

      DEALLOCATE(CWORK)

       CLOSE(53)
      ENDIF
!=======================================================================
!  STM calculation
!=======================================================================
      CALL  WRT_STM_FILE(GRID, WDES, WUP, EFERMI, LATT_CUR, STM, T_INFO)
      IF (WDES%ISPIN.EQ.2) &
      CALL  WRT_STM_FILE(GRID, WDES, WDW, EFERMI, LATT_CUR, STM, T_INFO)

!-MM- Writing to MAGCAR
      IF (WRITE_MOMENTS()) CALL WR_MOMENTS(GRID,LATT_CUR,P,T_INFO,W,WDES,.TRUE.)
      IF (WRITE_DENSITY()) CALL WR_PROJ_CHARG(GRID,P,LATT_CUR,T_INFO,WDES)
      IF (LCALC_ORBITAL_MOMENT().AND.WDES%LNONCOLLINEAR) CALL WRITE_ORBITAL_MOMENT(WDES,T_INFO%NIONS,IO%IU6)
!-MM- end of addition

!=======================================================================
!  calculate ion and lm decomposed occupancies and dos
!=======================================================================
      IF (JOBPAR/=0 .OR. IO%LORBIT>=10 ) THEN

      IF (NPAR /=1.AND. IO%LORBIT<10) THEN
         CALL VTUTOR('W','partial DOS',RTUT,1, &
     &                  ITUT,1,CDUM,1,LDUM,1,IO%IU6,IO%IDIOT)
         CALL VTUTOR('W','partial DOS',RTUT,1, &
     &                  ITUT,1,CDUM,1,LDUM,1,IO%IU0,IO%IDIOT)
      ELSE

       DEALLOCATE(PAR,DOSPAR)

       
       IF (IO%LORBIT==11 .OR. IO%LORBIT==1 .OR. IO%LORBIT==12 .OR. IO%LORBIT==2) THEN
          LPAR=LMDIMP
       ELSE
          LPAR=LDIMP
       ENDIF
       
       ALLOCATE(PAR(WDES%NB_TOT,WDES%NKDIM,LPAR,T_INFO%NIONP,WDES%NCDIJ))

       IF (IO%LORBIT>=10) THEN
          CALL SPHPRO_FAST( &
          GRID,LATT_CUR,LATT_INI, P,T_INFO,W, WDES, 71,IO%IU6,&
          INFO%LOVERL,LMDIM,CQIJ, LPAR, LDIMP, LMDIMP, .TRUE., IO%LORBIT,PAR)
       ELSE
          CALL SPHPRO( &
          GRID,LATT_CUR,LATT_INI, P,T_INFO,W, WDES, 71,IO%IU6,&
          INFO%LOVERL,LMDIM,CQIJ, LPAR, LDIMP, LMDIMP, LTRUNC, IO%LORBIT,PAR)
       ENDIF


       CALL CHGLOC(WDES%NB_TOT,KPOINTS%NKDIM,LPAR,T_INFO%NIONS,WDES%ISPIN,PAR,W%FERWE)

       !  get and write partial / projected DOS ...

       !  some compilers require to remove this statment
       DEALLOCATE(W%CPTWFP)         ! make space free so that DOSPAR can take this space
       ALLOCATE (DOSPAR(NEDOS,LPAR,T_INFO%NIONP,WDES%NCDIJ))
       SIGMA=ABS(KPOINTS%SIGMA)
       CALL DENSTA( IO%IU0, IO%IU6, WDES, W, KPOINTS, INFO%NELECT, &
               INFO%NUP_DOWN, E%EENTROPY, EFERMI, SIGMA, &
               NEDOS, LPAR, T_INFO%NIONP, DOS, DOSI, PAR, DOSPAR)
       
       DELTAE=(KPOINTS%EMAX-KPOINTS%EMIN)/(NEDOS-1)

       DO NI=1,T_INFO%NIONP
          WRITE(16,'(2F16.8,I5,2F16.8)') KPOINTS%EMAX,KPOINTS%EMIN,NEDOS,EFERMI,1.0
          DO I=1,NEDOS
             EN=KPOINTS%EMIN+DELTAE*(I-1)
             WRITE(16,87063) &
     &            EN,((DOSPAR(I,LPRO,NI,ISP),ISP=1,WDES%NCDIJ),LPRO=1,LPAR)
          ENDDO
       ENDDO

       CALL XML_DOS(EFERMI, KPOINTS%EMIN, KPOINTS%EMAX, .TRUE., &
          DOS, DOSI, DOSPAR, NEDOS, LPAR, T_INFO%NIONP, WDES%NCDIJ)
87063  FORMAT(3X,F8.3,36E12.4)
       CALL XML_PROCAR(PAR, W%CELTOT, W%FERTOT, WDES%NB_TOT, WDES%NKDIM, LPAR ,T_INFO%NIONP,WDES%NCDIJ)
       
      ENDIF
      ENDIF
      CALL XML_CLOSE_TAG

      CALL XML_TAG("structure","finalpos")
      CALL XML_CRYSTAL(LATT_CUR%A, LATT_CUR%B, LATT_CUR%OMEGA)
      CALL XML_POSITIONS(T_INFO%NIONS, DYN%POSION)
      IF (T_INFO%LSDYN) CALL XML_LSDYN(T_INFO%NIONS,T_INFO%LSFOR(3,NIOND))
      IF (DYN%IBRION<=0 .AND. DYN%NSW>0 ) CALL XML_VEL(T_INFO%NIONS, DYN%VEL)
      IF (T_INFO%LSDYN) CALL XML_NOSE(DYN%SMASS)
      CALL XML_CLOSE_TAG("structure")

!=======================================================================
! breath a sigh of relief - you have finished
! this jump is just a jump to the END statement
!=======================================================================


      GOTO 5100
!=======================================================================
!
!  here we have sum code to test performance
!  Output is written to IUT
!
!=======================================================================
 5000 CONTINUE
      
      IUT=IO%IU0

      IF (IUT>0) WRITE(IUT,5001)
 5001 FORMAT(/ &
     & ' All results refer to a run over all bands and one k-point'/ &
     & ' VNLACC   non local part of H'/ &
     & ' PROJ     calculate projection of all bands (contains FFTWAV)'/ &
     & ' RACC     non local part of H in real space (contains FFTEXT)'/ &
     & ' RPRO     calculate projection of all bands in real space '/ &
     & '          both calls contain on FFT (to be subtracted)'/ &
     & ' FFTWAV   FFT of a wavefunction to real space'/ &
     & ' FFTEXT   FFT to real space'/ &
     & ' ECCP     internal information only (subtract FFTWAV)'/ &
     & ' POTLOK   update of local potential (including one FFT)'/ &
     & ' SETDIJ   calculate stregth of US PP'/ &
     & ' ORTHCH   gramm-schmidt orth.  applying Choleski decomp.'/ &
     & ' LINCOM   unitary transformation of wavefunctions'/ &
     & ' LINUP    upper triangle transformation of wavefunctions'/ &
     & ' ORTHON   orthogonalisation of one band to all others')
       


! set the wavefunction descriptor
      ISP=1
      NK=1
      CALL SETWDES(WDES,WDES1,NK); CALL SETWGRID(WDES1,GRID)

      INFO%ISPIN=1
      INFO%RSPIN=2

      NPL=WDES%NPLWKP(NK)
      ALLOCATE(CWORK1(GRID%MPLWV),CWORK2(GRID%MPLWV),CPROTM(LMDIM*NIOND))
      W1%CR=>CWORK1

      

      CALL VTIME(TV0,TC0)
      CALL STUFAK(GRIDC,T_INFO,CSTRF)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'STUFAK',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL POTLOK(GRID,GRIDC,GRID_SOFT, WDES%COMM_INTER, WDES, &
                  EXCTAB,INFO,P,T_INFO,E,LATT_CUR,DIP, &
                  CHTOT,CSTRF,CVTOT,DENCOR,SV, SOFT_TO_C,XCSIF)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'POTLOK ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL FORLOC(GRIDC,P,T_INFO,LATT_CUR, CHTOT,EIFOR)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FORLOC',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL SOFT_CHARGE(GRID,GRID_SOFT,W,WDES, CHDEN(1,1))

      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'CHSP  ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)

      CALL DEPLE(WDES,GRID_SOFT,GRIDC,GRIDUS,C_TO_US, &
               LATT_CUR,P,T_INFO,SYMM, INFO%LOVERL, SOFT_TO_C,&
               LMDIM,CRHODE, CHTOT,CHDEN, IRDMAX)

      CALL SET_RHO_PAW(WDES, P, T_INFO, INFO%LOVERL, WDES%NCDIJ, LMDIM, &
           CRHODE, RHOLM)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'DEPLE ',TV-TV0,TC-TC0

      IF (INFO%LREAL) THEN

        CALL VTIME(TV0,TC0)
        CALL RSPHER(GRID,NONLR_S,LATT_CUR)
        CALL VTIME(TV,TC)
        IF (IUT>0) WRITE(IUT,2300)'RSPHER',TV-TV0,TC-TC0
        CWORK2=0
        CALL VTIME(TV0,TC0)
        CALL RACCT(NONLR_S,WDES,W,GRID,CDIJ,CQIJ,LMDIM, NK)
        CALL VTIME(TV,TC)
        IF (IUT>0) WRITE(IUT,2300)'RACC',TV-TV0,TC-TC0

      ELSE

        CALL PHASE(WDES,NONL_S,NK)
        NPL=WDES%NPLWKP(NK)
        CALL VTIME(TV0,TC0)
        DO N=1,WDES%NBANDS
          EVALUE=W%CELEN(N,1,1)
          CALL SETWAV(WUP,W1,N,NK)  ! allocation for W1%CR done above
          CALL VNLACC(NONL_S,WDES1,W1, LMDIM,CDIJ,CQIJ,EVALUE,  CWORK2)
        ENDDO
        CALL VTIME(TV,TC)
        IF (IUT>0) WRITE(IUT,2300)'VNLACC',TV-TV0,TC-TC0
      ENDIF


      CALL VTIME(TV0,TC0)
      IF (INFO%LREAL) THEN
        CALL VTIME(TV0,TC0)
        CALL RPRO(NONLR_S,WDES,W,GRID,NK)
        CALL VTIME(TV,TC)
        IF (IUT>0) WRITE(IUT,2300)'RPRO  ',TV-TV0,TC-TC0
      ELSE
        CALL PROJ(NONL_S,WDES,W,NK)
        CALL VTIME(TV,TC)
        IF (IUT>0) WRITE(IUT,2300)'PROJ  ',TV-TV0,TC-TC0
      ENDIF

      CALL VTIME(TV0,TC0)
      DO  N=1,WDES%NBANDS
        CALL FFTWAV(NPL,WDES%NINDPW(1,NK),CWORK1,W%CPTWFP(1,N,NK,1),GRID)
      ENDDO
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FFTWAV',TV-TV0,TC-TC0
      CALL VTIME(TV0,TC0)

      DO N=1,WDES%NBANDS
        CALL INIDAT(GRID%RC%NP,CWORK1)
      ENDDO
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FFTINI',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)

      DO N=1,WDES%NBANDS
        CALL INIDAT(GRID%RC%NP,CWORK1)
        CALL FFT3D(CWORK1,GRID,1)
      ENDDO
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FFT3DF',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)

      DO N=1,WDES%NBANDS
        CALL INIDAT(GRID%RC%NP,CWORK1)
        CALL FFT3D(CWORK1,GRID,1)
        CALL FFT3D(CWORK1,GRID,-1)
      ENDDO
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FFTFB ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      DO N=1,WDES%NBANDS
        CALL INIDAT(GRID%RL%NP,CWORK1)
        CALL FFTEXT(NPL,WDES%NINDPW(1,NK),CWORK1,CWORK2,GRID,.FALSE.)
      ENDDO

      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'FFTEXT ',TV-TV0,TC-TC0
      CALL VTIME(TV0,TC0)
      DO N=1,WDES%NBANDS
          CALL FFTWAV(NPL,WDES%NINDPW(1,NK),CWORK1,W%CPTWFP(1,N,NK,1),GRID)
          CALL SETWAV(WUP,W1,N,NK)  ! allocation for W1%CR done above
          CALL ECCP(WDES1,W1,W1,LMDIM,CDIJ,GRID,SV, W1%CELEN)
      ENDDO

      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'ECCP ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)

      CALL SETDIJ(WDES,GRIDC,GRIDUS,C_TO_US,LATT_CUR,P,T_INFO,INFO%LOVERL, &
                  LMDIM,CDIJ,CQIJ,CVTOT,IRDMAA,IRDMAX,.0_q,.0_q,.0_q)

      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'SETDIJ ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL SET_DD_PAW(WDES, P , T_INFO, INFO%LOVERL, &
         INFO%ISPIN, LMDIM, CDIJ,  RHOLM, CRHODE, INFO%LEXCH, INFO%LEXCHG, &
          E,  LMETA =  .FALSE., LASPH =.FALSE. , LCOREL=.FALSE.)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'SETPAW ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL ORTHCH(WDES,W, INFO%LOVERL, LMDIM,CQIJ,NBLK)
      CALL REDIS_PW_ALL(WDES, W)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'ORTHCH',(TV-TV0)/(KPOINTS%NKPTS),(TC-TC0)/KPOINTS%NKPTS

      CALL VTIME(TV0,TC0)
      IF (INFO%LDIAG) THEN
        IFLAG=3
      ELSE
        IFLAG=4
      ENDIF
      CALL EDDIAG(GRID,GRID,LATT_CUR,NONLR_S,NONL_S,W,WDES, &
          LMDIM,CDIJ,CQIJ, IFLAG,INFO%LOVERL,INFO%LREAL,NBLK,SV,IO%IU0, &
          E%EXHF,.FALSE.)

      CALL REDIS_PW_ALL(WDES, W)
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'EDDIAG',(TV-TV0)/(KPOINTS%NKPTS),(TC-TC0)/KPOINTS%NKPTS

! avoid that MATMUL is too clever
      ALLOCATE(CMAT(WDES%NB_TOT,WDES%NB_TOT))
      DO N1=1,WDES%NB_TOT
      DO N2=1,WDES%NB_TOT
        IF (N1==N2)  THEN
         CMAT(N1,N2)=0.99999_q
        ELSE
         CMAT(N1,N2)=EXP((0.7_q,0.5_q)/100)
       ENDIF
      ENDDO; ENDDO

      NPRO= WDES%NPRO
      
      NCPU=1
      NRPLWV_RED=WDES%NRPLWV/NCPU
      NPROD_RED =WDES%NPROD /NCPU

      CALL VTIME(TV0,TC0)
      CALL LINCOM('F',W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1),CMAT, &
       WDES%NB_TOT,WDES%NB_TOT,NPL,0,NRPLWV_RED,NPROD_RED,WDES%NB_TOT, &
       NBLK,W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1))
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'LINCOM',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL LINCOM('F',W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1),CMAT, &
       WDES%NB_TOT,WDES%NB_TOT,NPL,NPRO,NRPLWV_RED,NPROD_RED,WDES%NB_TOT, &
       NBLK,W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1))
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'LINCOM',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL LINCOM('U',W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1),CMAT, &
       WDES%NB_TOT,WDES%NB_TOT,NPL,NPRO,NRPLWV_RED,NPROD_RED,WDES%NB_TOT, &
       NBLK,W%CPTWFP(1,1,NK,1),W%CPROJ(1,1,NK,1))
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'LINUP ',TV-TV0,TC-TC0

      CALL VTIME(TV0,TC0)
      CALL NEWWAV(W1 ,WDES,GRID%MPLWV,.FALSE.)
      DO N=1,WDES%NBANDS
        CALL INIDAT(NPL,W1%CPTWFP)
        CALL INIDATR(WDES%NPRO,W1%CPROJ)
        CALL ORTHON(WDES,NK,W,W1, INFO%LOVERL,LMDIM,CQIJ,ISP)
      ENDDO
      CALL VTIME(TV,TC)
      IF (IUT>0) WRITE(IUT,2300)'ORTHO ',TV-TV0,TC-TC0
 5100 CONTINUE

      IF (MIX%IMIX==4 .AND. INFO%IALGO.NE.-1) THEN
        CALL CLBROYD(MIX%IUBROY)
      ENDIF

      IF (INFO%LSOFT) THEN
         
         IF (IO%IU0>0) &
         WRITE(TIU0,*) 'deleting file STOPCAR'
         IF (IO%LOPEN) OPEN(99,FILE='STOPCAR',ERR=5111)
         CLOSE(99,STATUS='DELETE',ERR=5111)
 5111    CONTINUE
         
      ENDIF

      CALL TIMING(0,UTIME,STIME,DAYTIM,MINPGF,MAJPGF, &
     &            RSIZM,AVSIZ,ISWPS,IOOPS,IVCSW,IERR)
      
      IF (IERR/=0) WRITE(TIU6,*) 'WARNING main: call to TIMING failed.'
      IF (IERR/=0) WRITE(TIU6,*) 'WARNING main: call to TIMING failed.'
      ETIME=DAYTIM-ETIME
      TOTTIM=UTIME+STIME
      WRITE(TIU6,*) ' '
      WRITE(TIU6,*) ' '
      WRITE(TIU6,'(A)') &
     &   ' General timing and accounting informations for this job:'
      WRITE(TIU6,'(A)') &
     &   ' ========================================================'
      WRITE(TIU6,*) ' '
      WRITE(TIU6,'(17X,A,F12.3)') ' Total CPU time used (sec): ',TOTTIM
      WRITE(TIU6,'(17X,A,F12.3)') '           User time (sec): ',UTIME
      WRITE(TIU6,'(17X,A,F12.3)') '         System time (sec): ',STIME
      WRITE(TIU6,'(17X,A,F12.3)') '        Elapsed time (sec): ',ETIME
      WRITE(TIU6,*) ' '
      WRITE(TIU6,'(17X,A,F12.0)') '  Maximum memory used (kb): ',RSIZM
      WRITE(TIU6,'(17X,A,F12.0)') '  Average memory used (kb): ',AVSIZ
      WRITE(TIU6,*) ' '
      WRITE(TIU6,'(17X,A,I12)')   '         Minor page faults: ',MINPGF
      WRITE(TIU6,'(17X,A,I12)')   '         Major page faults: ',MAJPGF
      WRITE(TIU6,'(17X,A,I12)')   'Voluntary context switches: ',IVCSW
      
      CALL STOP_XML
      
      END
