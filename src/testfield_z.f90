! $Id: testfield_z.f90,v 1.22 2008-03-12 17:52:36 brandenb Exp $

!  This modules deals with all aspects of testfield fields; if no
!  testfield fields are invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  testfield relevant subroutines listed in here.

!  Note: this routine requires that MVAR and MAUX contributions
!  together with njtest are set correctly in the cparam.local file.
!  njtest must be set at the end of the file such that 3*njtest=MVAR.
!
!  Example:
!  ! MVAR CONTRIBUTION 12
!  ! MAUX CONTRIBUTION 12
!  integer, parameter :: njtest=4

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Testfield

  use Cparam
  use Messages

  implicit none

  include 'testfield.h'
!
! Slice precalculation buffers
!
  real, target, dimension (nx,ny,3) :: bb11_xy
  real, target, dimension (nx,ny,3) :: bb11_xy2
  real, target, dimension (nx,nz,3) :: bb11_xz
  real, target, dimension (ny,nz,3) :: bb11_yz
!
!  cosine and sine function for setting test fields and analysis
!
  real, dimension(mz) :: cz,sz
!
  character (len=labellen), dimension(ninit) :: initaatest='nothing'
  real, dimension (ninit) :: amplaatest=0.

  ! input parameters
  real, dimension(3) :: B_ext=(/0.,0.,0./)
  real, dimension (nx,3) :: bbb
  real :: amplaa=0., kx_aa=1.,ky_aa=1.,kz_aa=1.
  real :: taainit=0.,daainit=0.
  logical :: reinitialize_aatest=.false.
  logical :: zextent=.true.,lsoca=.true.,lset_bbtest2=.false.
  logical :: luxb_as_aux=.false.,linit_aatest=.false.
  character (len=labellen) :: itestfield='B11-B21'
  real :: ktestfield=1., ktestfield1=1.
  integer, parameter :: ntestfield=3*njtest
  integer :: naainit
  real :: bamp=1.
  namelist /testfield_init_pars/ &
       B_ext,zextent,initaatest, &
       amplaatest, &
       luxb_as_aux

  ! run parameters
  real :: etatest=0.,etatest1=0.
  namelist /testfield_run_pars/ &
       B_ext,reinitialize_aatest,zextent,lsoca, &
       lset_bbtest2,etatest,etatest1,itestfield,ktestfield, &
       luxb_as_aux,daainit,linit_aatest,bamp

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_alp11=0      ! DIAG_DOC: $\alpha_{11}$
  integer :: idiag_alp21=0      ! DIAG_DOC: $\alpha_{21}$
  integer :: idiag_alp12=0      ! DIAG_DOC: $\alpha_{12}$
  integer :: idiag_alp22=0      ! DIAG_DOC: $\alpha_{22}$
  integer :: idiag_eta11=0      ! DIAG_DOC: $\eta_{113}k$
  integer :: idiag_eta21=0      ! DIAG_DOC: $\eta_{213}k$
  integer :: idiag_eta12=0      ! DIAG_DOC: $\eta_{123}k$
  integer :: idiag_eta22=0      ! DIAG_DOC: $\eta_{223}k$
  integer :: idiag_b0rms=0      ! DIAG_DOC: $\left<b_{0}^2\right>$
  integer :: idiag_b11rms=0     ! DIAG_DOC: $\left<b_{11}^2\right>$
  integer :: idiag_b21rms=0     ! DIAG_DOC: $\left<b_{21}^2\right>$
  integer :: idiag_b12rms=0     ! DIAG_DOC: $\left<b_{12}^2\right>$
  integer :: idiag_b22rms=0     ! DIAG_DOC: $\left<b_{22}^2\right>$
  integer :: idiag_E111z=0      ! DIAG_DOC: ${\cal E}_1^{11}$
  integer :: idiag_E211z=0      ! DIAG_DOC: ${\cal E}_2^{11}$
  integer :: idiag_E311z=0      ! DIAG_DOC: ${\cal E}_3^{11}$
  integer :: idiag_E121z=0      ! DIAG_DOC: ${\cal E}_1^{21}$
  integer :: idiag_E221z=0      ! DIAG_DOC: ${\cal E}_2^{21}$
  integer :: idiag_E321z=0      ! DIAG_DOC: ${\cal E}_3^{21}$
  integer :: idiag_E112z=0      ! DIAG_DOC: ${\cal E}_1^{12}$
  integer :: idiag_E212z=0      ! DIAG_DOC: ${\cal E}_2^{12}$
  integer :: idiag_E312z=0      ! DIAG_DOC: ${\cal E}_3^{12}$
  integer :: idiag_E122z=0      ! DIAG_DOC: ${\cal E}_1^{22}$
  integer :: idiag_E222z=0      ! DIAG_DOC: ${\cal E}_2^{22}$
  integer :: idiag_E322z=0      ! DIAG_DOC: ${\cal E}_3^{22}$
  integer :: idiag_E10z=0       ! DIAG_DOC: ${\cal E}_1^{0}$
  integer :: idiag_E20z=0       ! DIAG_DOC: ${\cal E}_2^{0}$
  integer :: idiag_E30z=0       ! DIAG_DOC: ${\cal E}_3^{0}$
  integer :: idiag_bx0mz=0      ! DIAG_DOC: $\left<b_{x}\right>_{xy}$
  integer :: idiag_by0mz=0      ! DIAG_DOC: $\left<b_{y}\right>_{xy}$
  integer :: idiag_bz0mz=0      ! DIAG_DOC: $\left<b_{z}\right>_{xy}$

  real, dimension (mz,3,ntestfield/3) :: uxbtestm

  contains

!***********************************************************************
    subroutine register_testfield()
!
!  Initialise variables which should know that we solve for the vector
!  potential: iaatest, etc; increase nvar accordingly
!
!   3-jun-05/axel: adapted from register_magnetic
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
      integer :: j
!
      if (.not. first) call stop_it('register_aa called twice')
      first=.false.
!
!  Set first and last index of text field
!  Here always ltestfield=T
!
      ltestfield=.true.
      iaatest=nvar+1
      iaxtest=iaatest
      iaxtestpq=iaatest+3*(njtest-1)
      iaztestpq=iaxtestpq+2
      nvar=nvar+ntestfield
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_testfield: nvar = ', nvar
        print*, 'register_testfield: iaatest = ', iaatest
      endif
!
!  Put variable names in array
!
      do j=1,ntestfield
        varname(j) = 'aatest'
      enddo
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: testfield_z.f90,v 1.22 2008-03-12 17:52:36 brandenb Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('register_testfield: nvar > mvar')
      endif
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',aatest $'
          if (nvar == mvar) write(4,*) ',aatest'
        else
          write(4,*) ',aatest $'
        endif
        write(15,*) 'aatest = fltarr(mx,my,mz,ntestfield)*one'
      endif
!
    endsubroutine register_testfield
!***********************************************************************
    subroutine initialize_testfield(f)
!
!  Perform any post-parameter-read initialization
!
!   2-jun-05/axel: adapted from magnetic
!
      use Cdata
      use FArrayManager
!
      real, dimension (mx,my,mz,mfarray) :: f
!
!  Precalculate etatest if 1/etatest (==etatest1) is given instead
!
      if (etatest1/=0.) then
        etatest=1./etatest1
      endif
!
!  set to zero and then rescale the testfield
!  (in future, could call something like init_aa_simple)
!
      if (reinitialize_aatest) then
        f(:,:,:,iaatest:iaatest+ntestfield-1)=0.
      endif
!
!  set cosine and sine function for setting test fields and analysis
!
      cz=cos(ktestfield*z)
      sz=sin(ktestfield*z)
!
!  Also calculate its inverse, but only if different from zero
!
      if (ktestfield==0) then
        ktestfield1=1.
      else
        ktestfield1=1./ktestfield
      endif
!
!  Register an extra aux slot for uxb if requested (so uxb is written
!  to snapshots and can be easily analyzed later). For this to work you
!  must reserve enough auxiliary workspace by setting, for example,
!     ! MAUX CONTRIBUTION 9
!  in the beginning of your src/cparam.local file, *before* setting
!  ncpus, nprocy, etc.
!
!  After a reload, we need to rewrite index.pro, but the auxiliary
!  arrays are already allocated and must not be allocated again.
!
      if (luxb_as_aux) then
        if (iuxb==0) then
          call farray_register_auxiliary('uxb',iuxb,vector=3*njtest)
        endif
        if (iuxb/=0.and.lroot) then
          print*, 'initialize_magnetic: iuxb = ', iuxb
          open(3,file=trim(datadir)//'/index.pro', POSITION='append')
          write(3,*) 'iuxb=',iuxb
          close(3)
        endif
      endif
!
!  write testfield information to a file (for convenient post-processing)
!
      if (lroot) then
        open(1,file=trim(datadir)//'/testfield_info.dat',STATUS='unknown')
        write(1,'(a,i1)') 'zextent=',merge(1,0,zextent)
        write(1,'(a,i1)') 'lsoca='  ,merge(1,0,lsoca)
        write(1,'(3a)') "itestfield='",trim(itestfield)//"'"
        write(1,'(a,f5.2)') 'ktestfield=',ktestfield
        close(1)
      endif
!
    endsubroutine initialize_testfield
!***********************************************************************
    subroutine init_aatest(f,xx,yy,zz)
!
!  initialise testfield; called from start.f90
!
!   2-jun-05/axel: adapted from magnetic
!
      use Cdata
      use Mpicomm
      use Initcond
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,tmp,prof
      real, dimension (nx,3) :: bb
      real, dimension (nx) :: b2,fact
      real :: beq2
      integer :: j
!
      do j=1,ninit

      select case(initaatest(j))

      case('zero'); f(:,:,:,iaatest:iaatest+ntestfield-1)=0.
      case('gaussian-noise-1'); call gaunoise(amplaatest(j),f,iaatest+0,iaatest+2)
      case('gaussian-noise-2'); call gaunoise(amplaatest(j),f,iaatest+3,iaatest+5)
      case('gaussian-noise-3'); call gaunoise(amplaatest(j),f,iaatest+6,iaatest+8)
      case('nothing'); !(do nothing)

      case default
        !
        !  Catch unknown values
        !
        if (lroot) print*, 'init_aatest: check initaatest: ', trim(initaatest(j))
        call stop_it("")

      endselect
      enddo
!
    endsubroutine init_aatest
!***********************************************************************
    subroutine pencil_criteria_testfield()
!
!   All pencils that the Testfield module depends on are specified here.
!
!  26-jun-05/anders: adapted from magnetic
!
      use Cdata
!
      lpenc_requested(i_uu)=.true.
!
    endsubroutine pencil_criteria_testfield
!***********************************************************************
    subroutine pencil_interdep_testfield(lpencil_in)
!
!  Interdependency among pencils from the Testfield module is specified here.
!
!  26-jun-05/anders: adapted from magnetic
!
      use Cdata
!
      logical, dimension(npencils) :: lpencil_in
!
    endsubroutine pencil_interdep_testfield
!***********************************************************************
    subroutine read_testfield_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=testfield_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=testfield_init_pars,ERR=99)
      endif

99    return
    endsubroutine read_testfield_init_pars
!***********************************************************************
    subroutine write_testfield_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=testfield_init_pars)

    endsubroutine write_testfield_init_pars
!***********************************************************************
    subroutine read_testfield_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=testfield_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=testfield_run_pars,ERR=99)
      endif

99    return
    endsubroutine read_testfield_run_pars
!***********************************************************************
    subroutine write_testfield_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=testfield_run_pars)

    endsubroutine write_testfield_run_pars
!***********************************************************************
    subroutine daatest_dt(f,df,p)
!
!  testfield evolution:
!
!  calculate da^(pq)/dt=Uxb^(pq)+uxB^(pq)+uxb-<uxb>+eta*del2A^(pq),
!    where p=1,2 and q=1 (if B11-B21) and optionally q=2 (if B11-B22)
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
      use Hydro, only: uumz,lcalc_uumean
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p

      real, dimension (nx,3) :: bb,aa,uxB,bbtest,btest,uxbtest,duxbtest
      real, dimension (nx,3,njtest) :: Eipq,bpq
      real, dimension (nx,3) :: del2Atest,uufluct
      real, dimension (nx,3) :: del2Atest2,graddivatest,aatest,jjtest,jxbrtest
      real, dimension (nx,3,3) :: aijtest,bijtest
      real, dimension (nx) :: bpq2
      integer :: jtest,jfnamez,j,i3,i4
      integer,save :: ifirst=0
      logical,save :: ltest_uxb=.false.
      character (len=5) :: ch
      character (len=130) :: file
!
      intent(in)     :: f,p
      intent(inout)  :: df
!
!  identify module and boundary conditions
!
      if (headtt.or.ldebug) print*,'daatest_dt: SOLVE'
      if (headtt) then
        if (iaxtest /= 0) call identify_bcs('Axtest',iaxtest)
        if (iaytest /= 0) call identify_bcs('Aytest',iaytest)
        if (iaztest /= 0) call identify_bcs('Aztest',iaztest)
      endif
!
!  calculate uufluct=U-Umean
!
      if (lcalc_uumean) then
        do j=1,3
          uufluct(:,j)=p%uu(:,j)-uumz(n,j)
        enddo
      else
        uufluct=p%uu
      endif
!
!  do each of the 9 test fields at a time
!  but exclude redundancies, e.g. if the averaged field lacks x extent.
!  Note: the same block of lines occurs again further down in the file.
!
      do jtest=1,njtest
        iaxtest=iaatest+3*(jtest-1)
        iaztest=iaxtest+2
        call del2v(f,iaxtest,del2Atest)
        select case(itestfield)
          case('B11-B21+B=0'); call set_bbtest(bbtest,jtest)
          case('B11-B21'); call set_bbtest_B11_B21(bbtest,jtest)
          case('B11-B22'); call set_bbtest_B11_B22(bbtest,jtest)
        case default
          call fatal_error('daatest_dt','undefined itestfield value')
        endselect
!
!  add an external field, if present
!
        if (B_ext(1)/=0.) bbtest(:,1)=bbtest(:,1)+B_ext(1)
        if (B_ext(2)/=0.) bbtest(:,2)=bbtest(:,2)+B_ext(2)
        if (B_ext(3)/=0.) bbtest(:,3)=bbtest(:,3)+B_ext(3)
!
        call cross_mn(uufluct,bbtest,uxB)
        if (lsoca) then
          df(l1:l2,m,n,iaxtest:iaztest)=df(l1:l2,m,n,iaxtest:iaztest) &
            +uxB+etatest*del2Atest
        else
!
!  use f-array for uxb (if space has been allocated for this) and
!  if we don't test (i.e. if ltest_uxb=.false.)
!
          if (iuxb/=0.and..not.ltest_uxb) then
            uxbtest=f(l1:l2,m,n,iuxb+3*(jtest-1):iuxb+3*jtest-1)
          else
            call curl(f,iaxtest,btest)
            call cross_mn(p%uu,btest,uxbtest)
          endif
!
!  subtract average emf
!
          do j=1,3
            duxbtest(:,j)=uxbtest(:,j)-uxbtestm(n,j,jtest)
          enddo
!
!  advance test field equation
!
          df(l1:l2,m,n,iaxtest:iaztest)=df(l1:l2,m,n,iaxtest:iaztest) &
            +uxB+etatest*del2Atest+duxbtest
!
!  Calculate Lorentz force
!
          if (ltestflow) then
            aatest=f(l1:l2,m,n,iaxtest:iaztest)
            call gij(f,iaatest,aijtest,1)
            call gij_etc(f,iaxtest,aatest,aijtest,bijtest,del2Atest2,graddivatest)
            call curl_mn(bijtest,jjtest,btest)
            call cross_mn(jjtest,btest,jxbrtest)
            df(l1:l2,m,n,iuxtest:iuztest)=df(l1:l2,m,n,iuxtest:iuztest) &
              +jxbrtest
          endif
!
        endif
!
!  calculate alpha, begin by calculating uxbtest (if not already done above)
!
        if ((ldiagnos.or.l1ddiagnos).and. &
          ((lsoca.or.iuxb/=0).and.(.not.ltest_uxb))) then
          call curl(f,iaxtest,btest)
          call cross_mn(p%uu,btest,uxbtest)
        endif
        bpq(:,:,jtest)=btest
        Eipq(:,:,jtest)=uxbtest/bamp
      enddo
!
!  diffusive time step, just take the max of diffus_eta (if existent)
!  and whatever is calculated here
!
      if (lfirst.and.ldt) then
        diffus_eta=max(diffus_eta,etatest*dxyz_2)
      endif
!
!  in the following block, we have already swapped the 4-6 entries with 7-9
!  The g95 compiler doesn't like to see an index that is out of bounds,
!  so prevent this warning by writing i3=3 and i4=4
!
      i3=3
      i4=4
      if (ldiagnos) then
        if (idiag_bx0mz/=0) call xysum_mn_name_z(bpq(:,1,i3),idiag_bx0mz)
        if (idiag_by0mz/=0) call xysum_mn_name_z(bpq(:,2,i3),idiag_by0mz)
        if (idiag_bz0mz/=0) call xysum_mn_name_z(bpq(:,3,i3),idiag_bz0mz)
        if (idiag_E111z/=0) call xysum_mn_name_z(Eipq(:,1,1),idiag_E111z)
        if (idiag_E211z/=0) call xysum_mn_name_z(Eipq(:,2,1),idiag_E211z)
        if (idiag_E311z/=0) call xysum_mn_name_z(Eipq(:,3,1),idiag_E311z)
        if (idiag_E121z/=0) call xysum_mn_name_z(Eipq(:,1,2),idiag_E121z)
        if (idiag_E221z/=0) call xysum_mn_name_z(Eipq(:,2,2),idiag_E221z)
        if (idiag_E321z/=0) call xysum_mn_name_z(Eipq(:,3,2),idiag_E321z)
        if (idiag_E112z/=0) call xysum_mn_name_z(Eipq(:,1,i3),idiag_E112z)
        if (idiag_E212z/=0) call xysum_mn_name_z(Eipq(:,2,i3),idiag_E212z)
        if (idiag_E312z/=0) call xysum_mn_name_z(Eipq(:,3,i3),idiag_E312z)
        if (idiag_E122z/=0) call xysum_mn_name_z(Eipq(:,1,i4),idiag_E122z)
        if (idiag_E222z/=0) call xysum_mn_name_z(Eipq(:,2,i4),idiag_E222z)
        if (idiag_E322z/=0) call xysum_mn_name_z(Eipq(:,3,i4),idiag_E322z)
        if (idiag_E10z/=0) call xysum_mn_name_z(Eipq(:,1,i3),idiag_E10z)
        if (idiag_E20z/=0) call xysum_mn_name_z(Eipq(:,2,i3),idiag_E20z)
        if (idiag_E30z/=0) call xysum_mn_name_z(Eipq(:,3,i3),idiag_E30z)
!
!  alpha and eta
!
        if (idiag_alp11/=0) call sum_mn_name(+cz(n)*Eipq(:,1,1)+sz(n)*Eipq(:,1,2),idiag_alp11)
        if (idiag_alp21/=0) call sum_mn_name(+cz(n)*Eipq(:,2,1)+sz(n)*Eipq(:,2,2),idiag_alp21)
        if (idiag_eta11/=0) call sum_mn_name((-sz(n)*Eipq(:,1,1)+cz(n)*Eipq(:,1,2))*ktestfield1,idiag_eta11)
        if (idiag_eta21/=0) call sum_mn_name((-sz(n)*Eipq(:,2,1)+cz(n)*Eipq(:,2,2))*ktestfield1,idiag_eta21)
!
!  print warning if alp12 and alp12 are needed, but njtest is too small XX
!
        if ((idiag_alp12/=0.or.idiag_alp22/=0 &
         .or.idiag_eta12/=0.or.idiag_eta22/=0).and.njtest<=2) then
          call stop_it('njtest is too small if alp12, alp22, eta12, or eta22 are needed')
        else
          if (idiag_alp12/=0) call sum_mn_name(+cz(n)*Eipq(:,1,i3)+sz(n)*Eipq(:,1,i4),idiag_alp12)
          if (idiag_alp22/=0) call sum_mn_name(+cz(n)*Eipq(:,2,i3)+sz(n)*Eipq(:,2,i4),idiag_alp22)
          if (idiag_eta12/=0) call sum_mn_name((-sz(n)*Eipq(:,1,i3)+cz(n)*Eipq(:,1,i4))*ktestfield1,idiag_eta12)
          if (idiag_eta22/=0) call sum_mn_name((-sz(n)*Eipq(:,2,i3)+cz(n)*Eipq(:,2,i4))*ktestfield1,idiag_eta22)
        endif
!
!  rms values of small scales fields bpq in response to the test fields Bpq
!  Obviously idiag_b0rms and idiag_b12rms cannot both be invoked!
!  Needs modification!
!
        if (idiag_b0rms/=0) then
          call dot2(bpq(:,:,i3),bpq2)
          call sum_mn_name(bpq2,idiag_b0rms,lsqrt=.true.)
        endif
!
        if (idiag_b11rms/=0) then
          call dot2(bpq(:,:,1),bpq2)
          call sum_mn_name(bpq2,idiag_b11rms,lsqrt=.true.)
        endif
!
        if (idiag_b21rms/=0) then
          call dot2(bpq(:,:,2),bpq2)
          call sum_mn_name(bpq2,idiag_b21rms,lsqrt=.true.)
        endif
!
        if (idiag_b12rms/=0) then
          call dot2(bpq(:,:,i3),bpq2)
          call sum_mn_name(bpq2,idiag_b12rms,lsqrt=.true.)
        endif
!
        if (idiag_b22rms/=0) then
          call dot2(bpq(:,:,i4),bpq2)
          call sum_mn_name(bpq2,idiag_b22rms,lsqrt=.true.)
        endif
!
      endif
!
!  write B-slices for output in wvid in run.f90
!  Note: ix is the index with respect to array with ghost zones.
! 
      if (lvid.and.lfirst) then
        do j=1,3
          bb11_yz(m-m1+1,n-n1+1,j)=bpq(ix_loc-l1+1,j,1)
          if (m==iy_loc)  bb11_xz(:,n-n1+1,j)=bpq(:,j,1)
          if (n==iz_loc)  bb11_xy(:,m-m1+1,j)=bpq(:,j,1)
          if (n==iz2_loc) bb11_xy2(:,m-m1+1,j)=bpq(:,j,1)
        enddo
      endif
!
! initialize aatest periodically if requested
!
      if (linit_aatest) then
         file=trim(datadir)//'/tinit_aatest.dat'
         if (ifirst==0) then
            call read_snaptime(trim(file),taainit,naainit,daainit,t)
            if (taainit==0 .or. taainit < t-daainit) then
              taainit=t+daainit
            endif
            ifirst=1
         endif
!
         if (t >= taainit) then
            reinitialize_aatest=.true.
            call initialize_testfield(f)
            reinitialize_aatest=.false.
            call update_snaptime(file,taainit,naainit,daainit,t,ltestfield,ch,ENUM=.false.)
         endif
      endif
!
    endsubroutine daatest_dt
!***********************************************************************
    subroutine get_slices_testfield(f,slices)
! 
!  Write slices for animation of magnetic variables.
! 
!  12-sep-09/axel: adapted from the corresponding magnetic routine
! 
      real, dimension (mx,my,mz,mfarray) :: f
      type (slice_data) :: slices
! 
!  Loop over slices
! 
      select case (trim(slices%name))
!
!  Magnetic field (derived variable)
!
        case ('bb11')
          if (slices%index >= 3) then
            slices%ready = .false.
          else
            slices%index = slices%index+1
            slices%yz=>bb11_yz(:,:,slices%index)
            slices%xz=>bb11_xz(:,:,slices%index)
            slices%xy=>bb11_xy(:,:,slices%index)
            slices%xy2=>bb11_xy2(:,:,slices%index)
            if (slices%index < 3) slices%ready = .true.
          endif
      endselect
!
    endsubroutine get_slices_testfield
!***********************************************************************
    subroutine calc_ltestfield_pars(f)
!
!  calculate <uxb>, which is needed when lsoca=.false.
!
!  21-jan-06/axel: coded
!
      use Cdata
      use Sub
      use Hydro, only: calc_pencils_hydro
      use Mpicomm, only: mpireduce_sum, mpibcast_real
!
      real, dimension (mx,my,mz,mfarray) :: f
!
      real, dimension (nz,nprocz,3,njtest) :: uxbtestm1
      real, dimension (nz*nprocz*3*njtest) :: uxbtestm2,uxbtestm3
      real, dimension (nx,3) :: btest,uxbtest
      integer :: jtest,j,nxy=nxgrid*nygrid,juxb
      logical :: headtt_save
      real :: fac
      type (pencil_case) :: p
!
      intent(inout) :: f
!
!  In this routine we will reset headtt after the first pencil,
!  so we need to reset it afterwards.
!
      headtt_save=headtt
      fac=1./nxy
!
!  do each of the 9 test fields at a time
!  but exclude redundancies, e.g. if the averaged field lacks x extent.
!  Note: the same block of lines occurs again further up in the file.
!
      do jtest=1,njtest
        iaxtest=iaatest+3*(jtest-1)
        iaztest=iaxtest+2
        if (lsoca) then
          uxbtestm(:,:,jtest)=0.
        else
          do n=n1,n2
            uxbtestm(n,:,jtest)=0.
            do m=m1,m2
              call calc_pencils_hydro(f,p)
              call curl(f,iaxtest,btest)
              call cross_mn(p%uu,btest,uxbtest)
!if (n==11.and.jtest==1) print*,'iproc,m,u,b,uxb=',iproc,m,btest(11,2),f(14,m,11,1),f(14,m,11,3)
              juxb=iuxb+3*(jtest-1)
              if (iuxb/=0) f(l1:l2,m,n,juxb:juxb+2)=uxbtest
              do j=1,3
                uxbtestm(n,j,jtest)=uxbtestm(n,j,jtest)+fac*sum(uxbtest(:,j))
              enddo
              headtt=.false.
            enddo
            do j=1,3
              uxbtestm1(n-n1+1,ipz+1,j,jtest)=uxbtestm(n,j,jtest)
            enddo
          enddo
        endif
      enddo
!
!  do communication for array of size nz*nprocz*3*njtest
!
      if (nprocy>1) then
        uxbtestm2=reshape(uxbtestm1,shape=(/nz*nprocz*3*njtest/))
!print*,iproc,uxbtestm(11,1,1)
!print*,iproc,uxbtestm1(11-n1+1,ipz+1,1,1),uxbtestm2(11-n1+1+nz*ipz)
        call mpireduce_sum(uxbtestm2,uxbtestm3,nz*nprocz*3*njtest)
        call mpibcast_real(uxbtestm3,nz*nprocz*3*njtest)
        uxbtestm1=reshape(uxbtestm3,shape=(/nz,nprocz,3,njtest/))
        do jtest=1,njtest
          do n=n1,n2
            do j=1,3
              uxbtestm(n,j,jtest)=uxbtestm1(n-n1+1,ipz+1,j,jtest)
            enddo
          enddo
        enddo
      endif
!
!  reset headtt
!
      headtt=headtt_save
!
    endsubroutine calc_ltestfield_pars
!***********************************************************************
    subroutine set_bbtest(bbtest,jtest)
!
!  set testfield
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=cz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=sz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.   ; bbtest(:,2)=0.; bbtest(:,3)=0.
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest
!***********************************************************************
    subroutine set_bbtest_B11_B21 (bbtest,jtest)
!
!  set testfield
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=cz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=sz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest_B11_B21
!***********************************************************************
    subroutine set_bbtest_B11_B22 (bbtest,jtest)
!
!  set testfield
!
!   3-jun-05/axel: coded
!
      use Cdata
      use Sub
!
      real, dimension (nx,3) :: bbtest
      integer :: jtest
!
      intent(in)  :: jtest
      intent(out) :: bbtest
!
!  set bbtest for each of the 9 cases
!
      select case(jtest)
      case(1); bbtest(:,1)=bamp*cz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case(2); bbtest(:,1)=bamp*sz(n); bbtest(:,2)=0.; bbtest(:,3)=0.
      case(3); bbtest(:,1)=0.; bbtest(:,2)=bamp*cz(n); bbtest(:,3)=0.
      case(4); bbtest(:,1)=0.; bbtest(:,2)=bamp*sz(n); bbtest(:,3)=0.
      case default; bbtest(:,:)=0.
      endselect
!
    endsubroutine set_bbtest_B11_B22
!***********************************************************************
    subroutine rprint_testfield(lreset,lwrite)
!
!  reads and registers print parameters relevant for testfield fields
!
!   3-jun-05/axel: adapted from rprint_magnetic
!
      use Cdata
      use Sub
!
      integer :: iname,inamez,inamexz
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of RELOAD
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_bx0mz=0; idiag_by0mz=0; idiag_bz0mz=0
        idiag_E111z=0; idiag_E211z=0; idiag_E311z=0
        idiag_E121z=0; idiag_E221z=0; idiag_E321z=0
        idiag_E10z=0; idiag_E20z=0; idiag_E30z=0
        idiag_alp11=0; idiag_alp21=0; idiag_alp12=0; idiag_alp22=0
        idiag_eta11=0; idiag_eta21=0; idiag_eta12=0; idiag_eta22=0
        idiag_b11rms=0; idiag_b21rms=0; idiag_b12rms=0; idiag_b22rms=0; idiag_b0rms=0
      endif
!
!  check for those quantities that we want to evaluate online
! 
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'alp11',idiag_alp11)
        call parse_name(iname,cname(iname),cform(iname),'alp21',idiag_alp21)
        call parse_name(iname,cname(iname),cform(iname),'alp12',idiag_alp12)
        call parse_name(iname,cname(iname),cform(iname),'alp22',idiag_alp22)
        call parse_name(iname,cname(iname),cform(iname),'eta11',idiag_eta11)
        call parse_name(iname,cname(iname),cform(iname),'eta21',idiag_eta21)
        call parse_name(iname,cname(iname),cform(iname),'eta12',idiag_eta12)
        call parse_name(iname,cname(iname),cform(iname),'eta22',idiag_eta22)
        call parse_name(iname,cname(iname),cform(iname),'b11rms',idiag_b11rms)
        call parse_name(iname,cname(iname),cform(iname),'b21rms',idiag_b21rms)
        call parse_name(iname,cname(iname),cform(iname),'b12rms',idiag_b12rms)
        call parse_name(iname,cname(iname),cform(iname),'b22rms',idiag_b22rms)
        call parse_name(iname,cname(iname),cform(iname),'b0rms',idiag_b0rms)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bx0mz',idiag_bx0mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'by0mz',idiag_by0mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'bz0mz',idiag_bz0mz)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E111z',idiag_E111z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E211z',idiag_E211z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E311z',idiag_E311z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E121z',idiag_E121z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E221z',idiag_E221z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E321z',idiag_E321z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E112z',idiag_E112z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E212z',idiag_E212z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E312z',idiag_E312z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E122z',idiag_E122z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E222z',idiag_E222z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E322z',idiag_E322z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E10z',idiag_E10z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E20z',idiag_E20z)
        call parse_name(inamez,cnamez(inamez),cformz(inamez),'E30z',idiag_E30z)
      enddo
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!
      if (lwr) then
        write(3,*) 'idiag_alp11=',idiag_alp11
        write(3,*) 'idiag_alp21=',idiag_alp21
        write(3,*) 'idiag_alp12=',idiag_alp12
        write(3,*) 'idiag_alp22=',idiag_alp22
        write(3,*) 'idiag_eta11=',idiag_eta11
        write(3,*) 'idiag_eta21=',idiag_eta21
        write(3,*) 'idiag_eta12=',idiag_eta12
        write(3,*) 'idiag_eta22=',idiag_eta22
        write(3,*) 'idiag_b0rms=',idiag_b0rms
        write(3,*) 'idiag_b11rms=',idiag_b11rms
        write(3,*) 'idiag_b21rms=',idiag_b21rms
        write(3,*) 'idiag_b12rms=',idiag_b12rms
        write(3,*) 'idiag_b22rms=',idiag_b22rms
        write(3,*) 'idiag_bx0mz=',idiag_bx0mz
        write(3,*) 'idiag_by0mz=',idiag_by0mz
        write(3,*) 'idiag_bz0mz=',idiag_bz0mz
        write(3,*) 'idiag_E111z=',idiag_E111z
        write(3,*) 'idiag_E211z=',idiag_E211z
        write(3,*) 'idiag_E311z=',idiag_E311z
        write(3,*) 'idiag_E121z=',idiag_E121z
        write(3,*) 'idiag_E221z=',idiag_E221z
        write(3,*) 'idiag_E321z=',idiag_E321z
        write(3,*) 'idiag_E112z=',idiag_E112z
        write(3,*) 'idiag_E212z=',idiag_E212z
        write(3,*) 'idiag_E312z=',idiag_E312z
        write(3,*) 'idiag_E122z=',idiag_E122z
        write(3,*) 'idiag_E222z=',idiag_E222z
        write(3,*) 'idiag_E322z=',idiag_E322z
        write(3,*) 'idiag_E10z=',idiag_E10z
        write(3,*) 'idiag_E20z=',idiag_E20z
        write(3,*) 'idiag_E30z=',idiag_E30z
        write(3,*) 'iaatest=',iaatest
        write(3,*) 'iaxtestpq=',iaxtestpq
        write(3,*) 'iaztestpq=',iaztestpq
        write(3,*) 'ntestfield=',ntestfield
        write(3,*) 'nnamez=',nnamez
        write(3,*) 'nnamexy=',nnamexy
        write(3,*) 'nnamexz=',nnamexz
      endif
!
    endsubroutine rprint_testfield

endmodule Testfield
