! $Id: nostruct_func.f90,v 1.7 2003-06-16 04:41:11 brandenb Exp $
!
module  struct_func
  !
  use Cdata
  !
  implicit none
  !
  contains

!***********************************************************************
    subroutine structure(f,ivec,b_vec,variabl)
!
  real, dimension (mx,my,mz,mvar+maux) :: f
  real, dimension (nx,ny,nz) :: b_vec
  integer :: ivec
  character (len=*) :: variabl
  !
  if(ip<=15) print*,'Use POWER=power_spectrum in Makefile.local'
  if(ip<=15) print*,'Use STRUCT_FUNC  = struct_func in Makefile.local'
  if(ip==0)  print*,f,ivec,b_vec,variabl  !(to keep compiler happy)
end subroutine structure
!***********************************************************************

end module struct_func
