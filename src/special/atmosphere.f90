! $Id: atmosphere.f90 12795 2010-04-14 17:03:07 ajohan@strw.leidenuniv.nl $
!
!  This module incorporates all the modules used for Natalia's
!  aerosol simulations 
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lspecial = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED ppsf(ndustspec); pp
!
!***************************************************************

!-------------------------------------------------------------------
!
! HOW TO USE THIS FILE
! --------------------
!
! The rest of this file may be used as a template for your own
! special module.  Lines which are double commented are intended
! as examples of code.  Simply fill out the prototypes for the
! features you want to use.
!
! Save the file with a meaningful name, eg. geo_kws.f90 and place
! it in the $PENCIL_HOME/src/special directory.  This path has
! been created to allow users ot optionally check their contributions
! in to the Pencil-Code CVS repository.  This may be useful if you
! are working on/using the additional physics with somebodyelse or
! may require some assistance from one of the main Pencil-Code team.
!
! To use your additional physics code edit the Makefile.local in
! the src directory under the run directory in which you wish to
! use your additional physics.  Add a line with all the module
! selections to say something like:
!
!    SPECIAL=special/atmosphere
!
! Where nstar it replaced by the filename of your new module
! upto and not including the .f90
!
!--------------------------------------------------------------------

module Special

  use Cparam
  use Cdata
  use Messages
  use Sub, only: keep_compiler_quiet
!  use Density, only: rho_up
  use EquationOfState


  implicit none

  include '../special.h'

  ! input parameters
  logical :: lbuoyancy_x=.false.
  logical :: lbuoyancy_z=.false.

  character (len=labellen) :: initstream='default'
  real, dimension(ndustspec) :: dsize
  real :: Rgas, Rgas_unit_sys=1.
  integer :: ind_water=0!, ind_cloud=0
  real :: sigma=1., Period=1.
  real :: dsize_max=0.,dsize_min=0.
  real :: TT2=0., TT1=0., dYw=1., pp_init=3.013e5
  integer :: ind_H2O=0, ind_N2
  logical :: lbuffer_zone_T=.false., lbuffer_zone_chem=.false.
  
! Keep some over used pencils
!
! start parameters
  namelist /atmosphere_init_pars/  &
      lbuoyancy_z,lbuoyancy_x, sigma, Period,dsize_max,dsize_min, &
      TT2,TT1,ind_H2O, ind_N2,dYw,lbuffer_zone_T, lbuffer_zone_chem, pp_init
         
! run parameters
  namelist /atmosphere_run_pars/  &
      lbuoyancy_z,lbuoyancy_x, sigma,dYw
!
!
  integer :: idiag_dtcrad=0
  integer :: idiag_dtchi=0
!
  contains

!***********************************************************************
    subroutine register_special()
!
!  Configure pre-initialised (i.e. before parameter read) variables
!  which should be know to be able to evaluate
!
!
!  6-oct-03/tony: coded
!
      use Cdata
   !   use Density
      use EquationOfState
      use Mpicomm
!
      logical, save :: first=.true.
!
! A quick sanity check
!
      if (.not. first) call stop_it('register_special called twice')
      first = .false.

!!
!! MUST SET lspecial = .true. to enable use of special hooks in the Pencil-Code
!!   THIS IS NOW DONE IN THE HEADER ABOVE
!
!
!
!!
!! Set any required f-array indexes to the next available slot
!!
!!
!      iSPECIAL_VARIABLE_INDEX = nvar+1             ! index to access entropy
!      nvar = nvar+1
!
!      iSPECIAL_AUXILIARY_VARIABLE_INDEX = naux+1             ! index to access entropy
!      naux = naux+1
!
!
!  identify CVS/SVN version information:
!
      if (lroot) call svn_id( &
           "$Id: atmosphere.f90 12795 2010-01-03 14:03:57Z ajohan@strw.leidenuniv.nl $")
!
!
!  Perform some sanity checks (may be meaningless if certain things haven't
!  been configured in a custom module but they do no harm)
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_special: naux > maux')
      endif
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_special: nvar > mvar')
      endif
!
    endsubroutine register_special
!***********************************************************************
    subroutine initialize_special(f,lstarting)
!
!  called by run.f90 after reading parameters, but before the time loop
!
!  06-oct-03/tony: coded
!
      use EquationOfState

      real, dimension (mx,my,mz,mvar+maux) :: f
      logical :: lstarting
      integer :: k,i
      real :: ddsize
!
!  Initialize any module variables which are parameter dependent
!
      if (unit_system == 'cgs') then
        Rgas_unit_sys = k_B_cgs/m_u_cgs
        Rgas=Rgas_unit_sys*unit_temperature/unit_velocity**2
      endif
!      
      do k=1,nchemspec
      !  if (trim(varname(ichemspec(k)))=='CLOUD') then
      !    ind_cloud=k
      !  endif
        if (trim(varname(ichemspec(k)))=='H2O') then
          ind_H2O=k
        endif
        if (trim(varname(ichemspec(k)))=='N2') then
          ind_N2=k
        endif
!        
      enddo
!    
      if (dsize_max/=0.0) then
          ddsize=(dsize_max-dsize_min)/(ndustspec-1)
          do i=0,(ndustspec-1)
            dsize(i+1)=dsize_min+i*ddsize
          enddo
        endif
!
   !   print*,'cloud index', ind_cloud
      print*,'water index', ind_H2O
      print*,'N2 index', ind_N2
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(lstarting)
!
    endsubroutine initialize_special
!***********************************************************************
    subroutine init_special(f)
!
!  initialise special condition; called from start.f90
!  06-oct-2003/tony: coded
!
      use Cdata
   !   use Density
      use EquationOfState
      use Mpicomm
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      intent(inout) :: f

!!
!      select case (initstream)
!        case ('flame_spd')
!         call flame_spd(f)
!        case ('default')
!          if (lroot) print*,'init_special: Default  setup'
!        case default
!
!  Catch unknown values
!
!          if (lroot) print*,'init_special: No such value for initstream: ', trim(initstream)
!          call stop_it("")
!      endselect
!
    endsubroutine init_special
!***********************************************************************
    subroutine pencil_criteria_special()
!
!  All pencils that this special module depends on are specified here.
!
!  18-07-06/tony: coded
!
      use Cdata
!
!
!
    endsubroutine pencil_criteria_special
!***********************************************************************
    subroutine dspecial_dt(f,df,p)
!
!  calculate right hand side of ONE OR MORE extra coupled PDEs
!  along the 'current' Pencil, i.e. f(l1:l2,m,n) where
!  m,n are global variables looped over in equ.f90
!
!  Due to the multi-step Runge Kutta timestepping used one MUST always
!  add to the present contents of the df array.  NEVER reset it to zero.
!
!  several precalculated Pencils of information are passed if for
!  efficiency.
!
!   06-oct-03/tony: coded
!
      use Cdata
      use Diagnostics
      use Mpicomm
      use Sub
   !   use Global
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p

!
      intent(in) :: f,p
      intent(inout) :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'dspecial_dt: SOLVE dSPECIAL_dt'
!!      if (headtt) call identify_bcs('ss',iss)
!
!!
!! SAMPLE DIAGNOSTIC IMPLEMENTATION
!!
      if (ldiagnos) then
        if (idiag_dtcrad/=0) &
          call max_mn_name(sqrt(advec_crad2)/cdt,idiag_dtcrad,l_dt=.true.)
        if (idiag_dtchi/=0) &
          call max_mn_name(diffus_chi/cdtv,idiag_dtchi,l_dt=.true.)
      endif

! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)

    endsubroutine dspecial_dt
!***********************************************************************
    subroutine read_special_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=atmosphere_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=atmosphere_init_pars,ERR=99)
      endif

99    return
    endsubroutine read_special_init_pars
!***********************************************************************
    subroutine write_special_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=atmosphere_init_pars)

    endsubroutine write_special_init_pars
!***********************************************************************
    subroutine read_special_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=atmosphere_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=atmosphere_run_pars,ERR=99)
      endif

99    return
    endsubroutine read_special_run_pars
!***********************************************************************
    subroutine write_special_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=atmosphere_run_pars)

    endsubroutine write_special_run_pars
!***********************************************************************
    subroutine rprint_special(lreset,lwrite)
!
!  reads and registers print parameters relevant to special
!
!   06-oct-03/tony: coded
!
      use Diagnostics
!
!  define diagnostics variable
!
      integer :: iname
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite

!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_dtcrad=0
        idiag_dtchi=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtcrad',idiag_dtcrad)
        call parse_name(iname,cname(iname),cform(iname),'dtchi',idiag_dtchi)
      enddo
!
!  write column where which magnetic variable is stored
      if (lwr) then
        write(3,*) 'i_dtcrad=',idiag_dtcrad
        write(3,*) 'i_dtchi=',idiag_dtchi
      endif
!
    endsubroutine rprint_special
!***********************************************************************
    subroutine calc_lspecial_pars(f)
!
!  dummy routine
!
!  15-jan-08/axel: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      intent(inout) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine calc_lspecial_pars
!***********************************************************************
    subroutine special_calc_density(f,df,p)
!
!   06-oct-03/tony: coded
!
      use Cdata
      ! use Viscosity
      use EquationOfState

      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_density
!***********************************************************************
    subroutine special_calc_hydro(f,df,p)
!
!   16-jul-06/natalia: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
!
      real :: gg=9.81e2, TT0=293, qwater0=9.9e-3
      real :: eps=0.5 !!????????????????????????
      real :: rho_water=1., const_tmp=0.
!
      real, dimension (mx) :: func_x
      integer :: j,i
      real :: dt1
      real :: del,width
!
       const_tmp=4./3.*PI*rho_water 
      if (lbuoyancy_z) then
        df(l1:l2,m,n,iuz)=df(l1:l2,m,n,iuz)&
             + gg*((p%TT(:)-TT0)/TT0 &
             + eps*(f(l1:l2,m,n,ichemspec(ind_water))-qwater0) &
             - p%fcloud(:) &
            )
      elseif (lbuoyancy_x) then
        df(l1:l2,m,n,iux)=df(l1:l2,m,n,iux)&
             + gg*((p%TT(:)-TT0)/TT0 &
             + eps*(f(l1:l2,m,n,ichemspec(ind_water))-qwater0) &
             - p%fcloud(:) &
            )
      endif
!
       dt1=1./dt
       del=0.1
!
!
       width=del*Lxyz(1)
!
         do i=1,mx 
  !       if ((x(i)<xyz0(1)+width) .or. (x(i)>xyz0(1)+Lxyz(1)-width)) then
         if ((x(i)<xyz0(1)+width)) then
!           df(i,m,n,iux)=df(i,m,n,iux)-(f(i,m,n,iux)-0.)*dt1/2.
!           df(i,m,n,ilnrho)=df(i,m,n,ilnrho)-(f(i,m,n,ilnrho)-alog(1e-3))*dt1/8.
         endif
         enddo
!
!
!
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)
!
    endsubroutine special_calc_hydro
!***********************************************************************
    subroutine special_calc_entropy(f,df,p)
!
      use Cdata
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      integer :: l_sz
      real, dimension (mx) :: func_x
      integer :: j,  sz_l_x,sz_r_x,ll1,ll2
      real :: dt1, lnTT_ref
      real :: del
      logical :: lzone=.false., lzone_left, lzone_right
!
       dt1=1./(3.*dt)
       del=0.1
!
!
         lzone_left=.false.
         lzone_right=.false.

         sz_r_x=l1+nxgrid-int(del*nxgrid)
         sz_l_x=int(del*nxgrid)+l1
!
         ll1=l1
         ll2=l2

        if (lbuffer_zone_T) then
        do j=1,2

         if (j==1) then
           lzone=.false.
           ll1=sz_r_x
           ll2=l2
           if (x(l2)==xyz0(1)+Lxyz(1)) lzone_right=.true.
           if (TT2>0.) then
            lnTT_ref=log(TT2)
            lzone=.true.
           endif
           if (lzone .and. lzone_right) then
!             df(ll1:ll2,m,n,ilnTT)=df(ll1:ll2,m,n,ilnTT)&
!              -(f(ll1:ll2,m,n,ilnTT)-lnTT_ref)*dt1
           endif
         elseif (j==2) then
           lzone=.false.
           ll1=l1
           ll2=sz_l_x
           if (x(l1)==xyz0(1)) lzone_left=.true.
           if (TT1>0.) then
            lnTT_ref=log(TT1)
            lzone=.true.
           endif
           if (lzone .and. lzone_left) then
             if (dYw==1.) then
               df(ll1:ll2,m,n,ilnTT)=df(ll1:ll2,m,n,ilnTT)&
                 -(f(ll1:ll2,m,n,ilnTT)-lnTT_ref)*dt1
             endif
           endif
         endif
!
!
        enddo
        endif
!
! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)

    endsubroutine special_calc_entropy
!***********************************************************************
   subroutine special_calc_chemistry(f,df,p)
!
      use Cdata
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension (mx,my,mz,mvar), intent(inout) :: df
      type (pencil_case), intent(in) :: p
      integer :: l_sz
      integer :: j,  sz_l_x,sz_r_x,ll1,ll2,lll1,lll2
      real :: dt1, lnTT_ref
      real :: del
      logical :: lzone=.false., lzone_left, lzone_right
!
       dt1=1./(3.*dt)
       del=0.1
!
!
         lzone_left=.false.
         lzone_right=.false.
!
        if (lbuffer_zone_chem) then
        do j=1,2
         if (ind_H2O>0) lzone=.true.
         if ((j==1) .and. (x(l2)==xyz0(1)+Lxyz(1))) then
           sz_r_x=l2-int(del*nxgrid)
           ll1=sz_r_x;  ll2=l2
           lll1=ll1-3; lll2=ll2-3  
           lzone_right=.true.
!              df(ll1:ll2,m,n,iuy)=  &
 !               df(ll1:ll2,m,n,iuy) &
 !              +(f(ll1:ll2,m,n,iuy) -0.)*dt1/5.

         elseif ((j==2) .and. ((x(l1)==xyz0(1)))) then
           sz_l_x=int(del*nxgrid)+l1
           ll1=l1;  ll2=sz_l_x
           lll1=ll1-3;  lll2=ll2-3
           lzone_left=.true.
!               df(ll1:ll2,m,n,iuy)=  &
!                df(ll1:ll2,m,n,iuy) &
!               +(f(ll1:ll2,m,n,iuy) -0.)*dt1/4.

         endif
!
         if ((lzone .and. lzone_right)) then
!           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll2,ind_H2O)/p%pp(lll2))*dt1
   
!           df(ll1:ll2,m,n,ichemspec(ind_N2))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_N2)) &
!               +(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1:lll2))*dt1
!            df(ll1:ll2,m,n,iux)=  &
!                df(ll1:ll2,m,n,iux) &
!               +(f(ll1:ll2,m,n,iux) -2.)*dt1/4.
         endif
        if ((lzone .and. lzone_left)) then
          if (dYw==1) then
           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1)*dYw)*dt1
               -p%ppsf(lll1:lll2,ind_H2O)/pp_init)*dt1

          else
           df(ll1:ll2,m,n,ichemspec(ind_H2O))=  &
                df(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
               -p%ppsf(lll1,ind_H2O)/p%pp(lll1)*dYw)*dt1
          endif
!           df(ll1:ll2,m,n,ichemspec(ind_N2))=  &
!                df(ll1:ll2,m,n,ichemspec(ind_N2)) &
!               +(f(ll1:ll2,m,n,ichemspec(ind_H2O)) &
!               -p%ppsf(lll1:lll2,ind_H2O)/p%pp(lll1:lll2))*dt1

          

         endif
!
        enddo
        endif
!
! Keep compiler quiet by ensuring every parameter is used
      call keep_compiler_quiet(df)
      call keep_compiler_quiet(p)

    endsubroutine special_calc_chemistry
!***********************************************************************
    subroutine special_boundconds(f,bc)
!
!   calculate a additional 'special' term on the right hand side of the
!   entropy equation.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-oct-03/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
      type (boundary_condition) :: bc
!


      select case (bc%bcname)
         case ('stm')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_stream_x(f,-1, bc)
           case (iBC_X_BOT)
             call bc_stream_x(f,-1, bc)
         endselect
         bc%done=.true.
         case ('cou')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_cos_ux(f,bc)
           case (iBC_X_BOT)
             call bc_cos_ux(f,bc)
           case (iBC_Y_TOP)
             call bc_cos_uy(f,bc)
           case (iBC_Y_BOT)
             call bc_cos_uy(f,bc)
         endselect
         bc%done=.true.
         case ('aer')
         select case (bc%location)
           case (iBC_X_TOP)
             call bc_aerosol_x(f,bc)
           case (iBC_X_BOT)
             call bc_aerosol_x(f,bc)
           case (iBC_Y_TOP)
             call bc_aerosol_y(f,bc)
           case (iBC_Y_BOT)
             call bc_aerosol_y(f,bc)
         endselect
         bc%done=.true.
         case ('sat')
         select case (bc%location)
           case (iBC_X_BOT)
             call bc_satur_x(f,bc)
         endselect
         bc%done=.true.
      endselect


      call keep_compiler_quiet(f)
      call keep_compiler_quiet(bc%bcname)
!
    endsubroutine special_boundconds
!***********************************************************************
!
!  PRIVATE UTITLITY ROUTINES
!
!***********************************************************************
   subroutine density_init(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
    endsubroutine density_init
!***************************************************************
    subroutine entropy_init(f)
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      endsubroutine entropy_init
!***********************************************************************
      subroutine velocity_init(f)
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
!
    endsubroutine  velocity_init
!***********************************************************************
!   INITIAL CONDITIONS
!
!**************************************************************************
!       BOUNDARY CONDITIONS
!**************************************************************************
  subroutine bc_stream_x(f,sgn,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: sgn
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2, rad_2
      real, dimension (2) :: jet_center=0.
      real, dimension (my,mz) :: u_profile
!
      do jjj=1,my
      do kkk=1,mz
         rad_2=((y(jjj)-jet_center(1))**2+(z(kkk)-jet_center(1))**2)
         u_profile(jjj,kkk)=exp(-rad_2/sigma**2)
      enddo
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
      ! bottom boundary
        f(l1,m1:m2,n1:n2,vr) = value1*u_profile(m1:m2,n1:n2)
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)+sgn*f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
      ! top boundary
        f(l2,m1:m2,n1:n2,vr) = value2*u_profile(m1:m2,n1:n2)
        do i=1,nghost; f(l2+i,:,:,vr)=2*f(l2,:,:,vr)+sgn*f(l2-i,:,:,vr); enddo
      else
        print*, "bc_BL_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_stream_x
!******************************************************************** 
  subroutine bc_cos_ux(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2
      real, dimension (my,mz) :: u_profile
!
      do jjj=1,my
         u_profile(jjj,:)=cos(Period*PI*y(jjj)/Lxyz(2))
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
      ! bottom boundary
        f(l1,m1:m2,n1:n2,vr) = value1*u_profile(m1:m2,n1:n2)
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
      ! top boundary
        f(l2,m1:m2,n1:n2,vr) = value2*u_profile(m1:m2,n1:n2)
        do i=1,nghost; f(l2+i,:,:,vr)=2*f(l2,:,:,vr)-f(l2-i,:,:,vr); enddo

      else
        print*, "bc_cos_ux: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_cos_ux
!******************************************************************** 
 subroutine bc_cos_uy(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr
      integer :: jjj,kkk
      real :: value1, value2
      real, dimension (mx,mz) :: u_profile
!
      do jjj=1,mx
         u_profile(jjj,:)=cos(Period*PI*x(jjj)/Lxyz(1))
      enddo
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_Y_BOT) then
      ! bottom boundary
        f(l1:l2,m1,n1:n2,vr) = value1*u_profile(l1:l2,n1:n2)
        do i=0,nghost; f(:,m1-i,:,vr)=2*f(:,m1,:,vr)-f(:,m1+i,:,vr); enddo
      elseif (bc%location==iBC_Y_TOP) then
      ! top boundary
        f(l1:l2,m2,n1:n2,vr) = value2*u_profile(l1:l2,n1:n2)
        do i=1,nghost; f(:,m2+i,:,vr)=2*f(:,m2,:,vr)-f(:,m2-i,:,vr); enddo
      else
        print*, "bc_cos_uy: ", bc%location, " should be `top(", &
                        iBC_Y_TOP,")' or `bot(",iBC_Y_BOT,")'"
      endif
!
    endsubroutine bc_cos_uy
!********************************************************************
 subroutine bc_aerosol_x(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr,k
      integer :: jjj,kkk
      real :: value1, value2
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
! bottom boundary
        if (vr==iuud(1)+3) then 
          do k=1,ndustspec
            f(l1,m1:m2,n1:n2,ind(k))=value1  &
            *exp(-((dsize(k)-(dsize_max+dsize_min)*0.5)/1e-4)**2)
          enddo
          do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
        endif
        if (vr==iuud(1)+4) then 
         f(l1,m1:m2,n1:n2,imd)=value1
        endif

!      if (vr==iuud(1)+3) then 
!        f(l1-1,:,:,ind)=0.2*(9*f(l1,:,:,ind)-4*f(l1+2,:,:,ind)  &
!                       -3*f(l1+3,:,:,ind)+3*f(l1+4,:,:,ind))
!        f(l1-2,:,:,ind)=0.2*(15*f(l1,:,:,ind)-2*f(l1+1,:,:,ind)  &
!                       -9*f(l1+2,:,:,ind)-6*f(l1+3,:,:,ind)+ 7*f(l1+4,:,:,ind))
!        f(l1-3,:,:,ind)=1./35.*(157*f(l1,:,:,ind)-33*f(l1+1,:,:,ind)-108*f(l1+2,:,:,ind)  &
!                     -68*f(l1+3,:,:,ind)+87*f(l1+4,:,:,ind))
!      endif
!      if (vr==iuud(1)+4) then 
!        f(l1-1,:,:,imd)=0.2*(  9*f(l1,:,:,imd)-4*f(l1+2,:,:,imd)-3*f(l1+3,:,:,imd)  &
!                       +3*f(l1+4,:,:,imd))
!        f(l1-2,:,:,imd)=0.2*( 15*f(l1,:,:,imd)-2*f(l1+1,:,:,imd)  &
!                       -9*f(l1+2,:,:,imd)-6*f(l1+3,:,:,imd)+ 7*f(l1+4,:,:,imd))
!        f(l1-3,:,:,imd)=1./35.*(157*f(l1,:,:,imd)-33*f(l1+1,:,:,imd)-108*f(l1+2,:,:,imd)  &
!                     -68*f(l1+3,:,:,imd)+87*f(l1+4,:,:,imd))
!      endif

      elseif (bc%location==iBC_X_TOP) then
! top boundary
!        if (vr==iuud(1)+3) then 
!          do k=1,ndustspec
!            f(l2,m1:m2,n1:n2,ind(k))=value2  &
!            *exp(-((dsize(k)-(dsize_max+dsize_min)*0.5)/2e-5)**2)
!          enddo
!          do i=0,nghost; f(l2+i,:,:,vr)=2*f(l2,:,:,vr)-f(l2-i,:,:,vr); enddo
!        endif
!        if (vr==iuud(1)+4) then 
!         f(l2,m1:m2,n1:n2,imd)=value2
!        endif
        if (vr>=iuud(1)+3) then 
        f(l2+1,:,:,ind)=0.2   *(  9*f(l2,:,:,ind)-  4*f(l2-2,:,:,ind) &
                       - 3*f(l2-3,:,:,ind)+ 3*f(l2-4,:,:,ind))
        f(l2+2,:,:,ind)=0.2   *( 15*f(l2,:,:,ind)- 2*f(l2-1,:,:,ind)  &
                 -  9*f(l2-2,:,:,ind)- 6*f(l2-3,:,:,ind)+ 7*f(l2-4,:,:,ind))
        f(l2+3,:,:,ind)=1./35.*(157*f(l2,:,:,ind)-33*f(l2-1,:,:,ind)  &
                       -108*f(l2-2,:,:,ind) -68*f(l2-3,:,:,ind)+87*f(l2-4,:,:,ind))
        endif
        if (vr==iuud(1)+4) then 
        f(l2+1,:,:,imd)=0.2   *(  9*f(l2,:,:,imd)-  4*f(l2-2,:,:,imd) &
                       - 3*f(l2-3,:,:,imd)+ 3*f(l2-4,:,:,imd))
        f(l2+2,:,:,imd)=0.2   *( 15*f(l2,:,:,imd)- 2*f(l2-1,:,:,imd)  &
                 -  9*f(l2-2,:,:,imd)- 6*f(l2-3,:,:,imd)+ 7*f(l2-4,:,:,imd))
        f(l2+3,:,:,imd)=1./35.*(157*f(l2,:,:,imd)-33*f(l2-1,:,:,imd)  &
                       -108*f(l2-2,:,:,imd) -68*f(l2-3,:,:,imd)+87*f(l2-4,:,:,imd))
        endif
      else
        print*, "bc_BL_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_aerosol_x
!********************************************************************
 subroutine bc_aerosol_y(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      integer :: i,j,vr,k
      integer :: jjj,kkk
      real :: value1, value2
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_Y_BOT) then
! bottom boundary
        if (vr>=iuud(1)+3) then 
        f(:,m1-1,:,ind)=0.2   *(  9*f(:,m1,:,ind)-  4*f(:,m1+2,:,ind) &
                       - 3*f(:,m1+3,:,ind)+ 3*f(:,m1+4,:,ind))
        f(:,m1-2,:,ind)=0.2   *( 15*f(:,m1,:,ind)- 2*f(:,m1+1,:,ind)  &
                 -  9*f(:,m1+2,:,ind)- 6*f(:,m1+3,:,ind)+ 7*f(:,m1+4,:,ind))
        f(:,m1-3,:,ind)=1./35.*(157*f(:,m1,:,ind)-33*f(:,m1+1,:,ind)  &
                       -108*f(:,m1+2,:,ind) -68*f(:,m1+3,:,ind)+87*f(:,m1+4,:,ind))
        endif
        if (vr==iuud(1)+4) then 
        f(:,m1-1,:,imd)=0.2   *(  9*f(:,m1,:,imd)-  4*f(:,m1+2,:,imd) &
                       - 3*f(:,m1+3,:,imd)+ 3*f(:,m1+4,:,imd))
        f(:,m1-2,:,imd)=0.2   *( 15*f(:,m1,:,imd)- 2*f(:,m1+1,:,imd)  &
                 -  9*f(:,m1+2,:,imd)- 6*f(:,m1+3,:,imd)+ 7*f(:,m1+4,:,imd))
        f(:,m1-3,:,imd)=1./35.*(157*f(:,m1,:,imd)-33*f(:,m1+1,:,imd)  &
                       -108*f(:,m1+2,:,imd) -68*f(:,m1+3,:,imd)+87*f(:,m1+4,:,imd))      
        endif
      elseif (bc%location==iBC_Y_TOP) then
! top boundary
        if (vr>=iuud(1)+3) then 
        f(:,m2+1,:,ind)=0.2   *(  9*f(:,m2,:,ind)-  4*f(:,m2-2,:,ind) &
                       - 3*f(:,m2-3,:,ind)+ 3*f(:,m2-4,:,ind))
        f(:,m2+2,:,ind)=0.2   *( 15*f(:,m2,:,ind)- 2*f(:,m2-1,:,ind)  &
                 -  9*f(:,m2-2,:,ind)- 6*f(:,m2-3,:,ind)+ 7*f(:,m2-4,:,ind))
        f(:,m2+3,:,ind)=1./35.*(157*f(:,m2,:,ind)-33*f(:,m2-1,:,ind)  &
                       -108*f(:,m2-2,:,ind) -68*f(:,m2-3,:,ind)+87*f(:,m2-4,:,ind))
        endif
        if (vr==iuud(1)+4) then 
        f(:,m2+1,:,imd)=0.2   *(  9*f(:,m2,:,imd)-  4*f(:,m2-2,:,imd) &
                       - 3*f(:,m2-3,:,imd)+ 3*f(:,m2-4,:,imd))
        f(:,m2+2,:,imd)=0.2   *( 15*f(:,m2,:,imd)- 2*f(:,m2-1,:,imd)  &
                 -  9*f(:,m2-2,:,imd)- 6*f(:,m2-3,:,imd)+ 7*f(:,m2-4,:,imd))
        f(:,m2+3,:,imd)=1./35.*(157*f(:,m2,:,imd)-33*f(:,m2-1,:,imd)  &
                       -108*f(:,m2-2,:,imd) -68*f(:,m2-3,:,imd)+87*f(:,m2-4,:,imd))
        endif
      else
        print*, "bc_BL_y: ", bc%location, " should be `top(", &
                        iBC_Y_TOP,")' or `bot(",iBC_Y_BOT,")'"
      endif
!
    endsubroutine bc_aerosol_y
!********************************************************************
subroutine bc_satur_x(f,bc)
!
! Natalia
!
    use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (boundary_condition) :: bc
      real, dimension (mx,my,mz) :: sum_Y
      integer :: i,j,vr,k
      integer :: jjj,kkk
      real :: value1, value2, pp_sat
!
      vr=bc%ivar
      value1=bc%value1
      value2=bc%value2
!
      if (bc%location==iBC_X_BOT) then
! bottom boundary
        if (vr==ilnTT) then 
          f(l1,m1:m2,n1:n2,ilnTT)=alog(TT1)
        endif
        if (vr==ichemspec(ind_H2O)) then 
         pp_sat=6.035e12*exp(-5938./TT1)
         f(l1,m1:m2,n1:n2,ichemspec(ind_H2O))=pp_sat/pp_init
        endif
!
        if (vr==ichemspec(ind_N2)) then 
          do k=1,nchemspec
           if (ichemspec(k)/=ind_N2) sum_Y=sum_Y+f(:,:,:,ichemspec(k))
          enddo
           f(:,:,:,ind_N2)=1.-sum_Y
        endif
!
        do i=0,nghost; f(l1-i,:,:,vr)=2*f(l1,:,:,vr)-f(l1+i,:,:,vr); enddo
      elseif (bc%location==iBC_X_TOP) then
! top boundary

      else
        print*, "bc_satur_x: ", bc%location, " should be `top(", &
                        iBC_X_TOP,")' or `bot(",iBC_X_BOT,")'"
      endif
!
    endsubroutine bc_satur_x
!********************************************************************
    subroutine special_before_boundary(f)
!
!   Possibility to modify the f array before the boundaries are
!   communicated.
!
!   Some precalculated pencils of data are passed in for efficiency
!   others may be calculated directly from the f array
!
!   06-jul-06/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(in) :: f
!
      call keep_compiler_quiet(f)
!
    endsubroutine special_before_boundary
!
!********************************************************************

!************        DO NOT DELETE THE FOLLOWING       **************
!********************************************************************
!**  This is an automatically generated include file that creates  **
!**  copies dummy routines from nospecial.f90 for any Special      **
!**  routines not implemented in this file                         **
!**                                                                **
    include '../special_dummies.inc'
!********************************************************************

endmodule Special

