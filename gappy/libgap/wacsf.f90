
SUBROUTINE CAR2ACSF(NA, max_neighbor, nf, pos, neighbor, neighbor_count, xx, dxdy, strs, lgrad)

implicit real(8) (a-h,o-z)
INTEGER, intent(in)                                      :: NA, max_neighbor, NF
REAL(8), intent(in), dimension(NA,3)                     :: pos
REAL(8), intent(in), dimension(NA,max_neighbor,6)        :: neighbor
INTEGER, intent(in), dimension(NA)                       :: neighbor_count
REAL(8), intent(out), dimension(NF, NA)                  :: xx
REAL(8), intent(out), dimension(NF,NA,NA,3)              :: dxdy
REAL(8), intent(out), dimension(3,3,NF,NA)               :: strs
LOGICAL, intent(in)                                      :: lgrad

!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
TYPE SF
INTEGER                                      :: ntype
REAL(8)                                      :: alpha
REAL(8)                                      :: cutoff
END TYPE SF

TYPE ACSF_type
INTEGER                                      :: nsf
REAL(8)                                      :: global_cutoff
type(SF),dimension(:),allocatable            :: sf
END TYPE ACSF_type
TYPE(ACSF_type)                              :: ACSF
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


!local
REAL(8),PARAMETER                            :: pi=3.141592654d0
REAL(8),dimension(3)                         :: xyz, xyz_j, xyz_k
logical                                      :: alive
INTEGER                                      :: nspecies
REAL(8)                                      :: weights, weights_j, weights_k
REAL(8)                                      :: rij, fcutij, rik, fcutik, rjk, fcutjk

natoms = size(neighbor,1)
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
inquire(file="gap_parameters",exist=alive)
if(.not.alive) then
    print*, "gap_parameters file does not exist!"
    stop
endif
open(2244,file='gap_parameters')
read(2244,*)  nspecies
do i = 1, nspecies
    read(2244, *)
enddo
!read(2244,*)  acsf%global_cutoff
read(2244,*)  acsf%nsf
allocate(acsf%sf(acsf%nsf))
do i = 1, acsf%nsf
    read(2244,*) acsf%sf(i)%ntype, acsf%sf(i)%alpha, acsf%sf(i)%cutoff
enddo
close(2244)
!XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
rmin = 0.5d0
nnn = ACSF%nsf

xx = 0.d0
dxdy = 0.d0
strs = 0.d0

do ii = 1, nnn
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
!G1 = SUM_j{exp(-alpha*rij**2)*fc(rij)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if (ACSF%sf(ii)%ntype.eq.1) then
        cutoff = ACSF%sf(ii)%cutoff
        alpha = ACSF%sf(ii)%alpha
        do i = 1, natoms
            ! ******************
            ! Be careful!!!
            ! i_type loop from 1 to data_c%nspecies not at%nspecies
            ! 2019.09.04 STUPID!!!
            ! ******************
            !do i_type = 1, data_c%nspecies
                do i_neighbor = 1, neighbor_count(i)
                    rij = neighbor(i, i_neighbor, 4)
                    if (rij.gt.cutoff) cycle
                    xyz = neighbor(i, i_neighbor, 1:3)
                    weights = neighbor(i, i_neighbor, 5)
                    n = int(neighbor(i, i_neighbor, 6))
                    fcutij = 0.5d0 * (dcos(pi*rij/cutoff) + 1.d0)
                    xx(ii,i) = xx(ii,i) + dexp(-1.d0*alpha*rij**2)*fcutij
                    xx(ii + nnn, i) = xx(ii + nnn, i) + dexp(-1.d0*alpha*rij**2)*fcutij * weights !!!!!!! 

                    if (lgrad) then
                        deltaxj = -1.d0*(pos(i, 1) - xyz(1))
                        deltayj = -1.d0*(pos(i, 2) - xyz(2))
                        deltazj = -1.d0*(pos(i, 3) - xyz(3))
                        drijdxi = -1.d0*deltaxj/rij
                        drijdyi = -1.d0*deltayj/rij
                        drijdzi = -1.d0*deltazj/rij
                        drijdxj = -1.d0*drijdxi
                        drijdyj = -1.d0*drijdyi
                        drijdzj = -1.d0*drijdzi
                        temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                        dfcutijdxi=temp1*drijdxi
                        dfcutijdyi=temp1*drijdyi
                        dfcutijdzi=temp1*drijdzi
                        dfcutijdxj=-1.d0*dfcutijdxi
                        dfcutijdyj=-1.d0*dfcutijdyi
                        dfcutijdzj=-1.d0*dfcutijdzi
                        !dxx/dx
                        temp1=-2.d0*alpha*rij*dexp(-1.d0*alpha*rij**2)*fcutij
                        temp2= dexp(-1.d0*alpha*rij**2)

                        dxdy(ii,i,i,1)=dxdy(ii,i,i,1)+(drijdxi*temp1 + temp2*dfcutijdxi)
                        dxdy(ii+nnn,i,i,1)=dxdy(ii+nnn,i,i,1) + (drijdxi*temp1+ temp2*dfcutijdxi) * weights
                
                        temp3=drijdxj*temp1 + temp2*dfcutijdxj
                        dxdy(ii,i,n,1)=dxdy(ii,i,n,1)+temp3
                
                        temp4=temp3*weights
                        dxdy(ii + nnn,i,n,1)=dxdy(ii + nnn,i,n,1)+temp4
                
                        strs(1,1,ii,i)=strs(1,1,ii,i)+deltaxj*temp3
                        strs(2,1,ii,i)=strs(2,1,ii,i)+deltayj*temp3
                        strs(3,1,ii,i)=strs(3,1,ii,i)+deltazj*temp3
                
                        strs(1,1,ii+nnn,i)=strs(1,1,ii+nnn,i)+deltaxj*temp4
                        strs(2,1,ii+nnn,i)=strs(2,1,ii+nnn,i)+deltayj*temp4
                        strs(3,1,ii+nnn,i)=strs(3,1,ii+nnn,i)+deltazj*temp4
                        !dxx/dy
                        dxdy(ii,i,i,2)=dxdy(ii,i,i,2)+(drijdyi*temp1+temp2*dfcutijdyi)
                        dxdy(ii+nnn,i,i,2)=dxdy(ii+nnn,i,i,2)+(drijdyi*temp1+temp2*dfcutijdyi)*weights
                        temp3= drijdyj*temp1 + temp2*dfcutijdyj
                        dxdy(ii,i,n,2)=dxdy(ii,i,n,2)+temp3
                        temp4=temp3 * weights
                        dxdy(ii + nnn,i,n,2)=dxdy(ii + nnn ,i,n,2)+temp4
                
                        strs(1,2,ii,i)=strs(1,2,ii,i)+deltaxj*temp3
                        strs(2,2,ii,i)=strs(2,2,ii,i)+deltayj*temp3
                        strs(3,2,ii,i)=strs(3,2,ii,i)+deltazj*temp3
                
                        strs(1,2,ii + nnn,i)=strs(1,2,ii + nnn,i)+deltaxj*temp4
                        strs(2,2,ii + nnn,i)=strs(2,2,ii + nnn,i)+deltayj*temp4
                        strs(3,2,ii + nnn,i)=strs(3,2,ii + nnn,i)+deltazj*temp4
                        !dxx/dz
                        dxdy(ii,i,i,3)=dxdy(ii,i,i,3)+&
                               (drijdzi*temp1&
                              + temp2*dfcutijdzi)
                        dxdy(ii + nnn,i,i,3)=dxdy(ii + nnn,i,i,3)+&
                               (drijdzi*temp1&
                              + temp2*dfcutijdzi)*weights
                        temp3=drijdzj*temp1 + temp2*dfcutijdzj
                        dxdy(ii,i,n,3)=dxdy(ii,i,n,3)+temp3
                        temp4=temp3*weights
                        dxdy(ii + nnn,i,n,3)=dxdy(ii + nnn,i,n,3)+temp4
                
                        strs(1,3,ii,i)=strs(1,3,ii,i)+deltaxj*temp3
                        strs(2,3,ii,i)=strs(2,3,ii,i)+deltayj*temp3
                        strs(3,3,ii,i)=strs(3,3,ii,i)+deltazj*temp3
                
                        strs(1,3,ii + nnn,i)=strs(1,3,ii + nnn,i)+deltaxj*temp4
                        strs(2,3,ii + nnn,i)=strs(2,3,ii + nnn,i)+deltayj*temp4
                        strs(3,3,ii + nnn,i)=strs(3,3,ii + nnn,i)+deltazj*temp4
                    endif ! lgrad
                enddo ! i_neighbor
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
! lamda = 1
! eta = 1
! G2 = SUM_jk{(1+lamda*costheta_ijk)^eta*
! exp(-alpha*(rij**2+rik**2+rjk**2))*fc(rij)*fc(rik)*fc(rjk)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.2) then
        cutoff = ACSF%sf(ii)%cutoff
        alpha = ACSF%sf(ii)%alpha
!        print*, 'cutoff',cutoff,'alpha',alpha
        do i = 1, natoms
!       lllll = 0
            do j_neighbor = 1, neighbor_count(i) 
                rij = neighbor(i, j_neighbor, 4)
                if (rij.gt.cutoff) cycle
                xyz_j = neighbor(i, j_neighbor, 1:3)
                fcutij=0.5d0*(dcos(pi*rij/cutoff)+1.d0)
                weights_j = neighbor(i, j_neighbor, 5)
                n = int(neighbor(i, j_neighbor, 6))
                if (lgrad) then
                    deltaxj = -1.d0*(pos(i, 1) - xyz_j(1))
                    deltayj = -1.d0*(pos(i, 2) - xyz_j(2))
                    deltazj = -1.d0*(pos(i, 3) - xyz_j(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    drijdxk = 0.d0
                    drijdyk = 0.d0
                    drijdzk = 0.d0
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    dfcutijdxk=0.0d0
                    dfcutijdyk=0.0d0
                    dfcutijdzk=0.0d0
                endif
                do k_neighbor = 1, neighbor_count(i)
                    ! ******************
                    ! Be careful
                    ! ******************
                    if (k_neighbor <= j_neighbor) cycle
                    rik = neighbor(i, k_neighbor,4)
                    if (rik.gt.cutoff) cycle
                    xyz_k = neighbor(i, k_neighbor,1:3)
                    weights_k = neighbor(i, k_neighbor,5)
                    m = int(neighbor(i, k_neighbor,6))
                    fcutik=0.5d0*(dcos(pi*rik/cutoff)+1.d0)
                    if (lgrad) then
                        deltaxk = -1.d0*(pos(i, 1) - xyz_k(1))
                        deltayk = -1.d0*(pos(i, 2) - xyz_k(2))
                        deltazk = -1.d0*(pos(i, 3) - xyz_k(3))
                        drikdxi = -deltaxk/rik
                        drikdyi = -deltayk/rik
                        drikdzi = -deltazk/rik
                        drikdxk = -1.d0*drikdxi
                        drikdyk = -1.d0*drikdyi
                        drikdzk = -1.d0*drikdzi
                        drikdxj = 0.d0
                        drikdyj = 0.d0
                        drikdzj = 0.d0
                        temp1=0.5d0*(-dsin(pi*rik/cutoff))*(pi/cutoff)
                        dfcutikdxi=temp1*drikdxi
                        dfcutikdyi=temp1*drikdyi
                        dfcutikdzi=temp1*drikdzi
                        dfcutikdxj=0.0d0
                        dfcutikdyj=0.0d0
                        dfcutikdzj=0.0d0
                        dfcutikdxk=-1.d0*dfcutikdxi
                        dfcutikdyk=-1.d0*dfcutikdyi
                        dfcutikdzk=-1.d0*dfcutikdzi
                    endif
                    rjk = (xyz_j(1) - xyz_k(1))**2 + (xyz_j(2) - xyz_k(2))**2 + (xyz_j(3) - xyz_k(3))**2
                    rjk = dsqrt(rjk)

                    if (rjk.gt.cutoff) cycle  ! CAUTAINS STUPID!!!
                    if (rjk < Rmin) then
                        print*, 'Rjk', rjk,' smaller than Rmin'
                    !    stop
                    endif
                    fcutjk=0.5d0*(dcos(pi*rjk/cutoff)+1.d0)
                    if (lgrad) then
                        drjkdxj = (xyz_j(1) - xyz_k(1))/rjk
                        drjkdyj = (xyz_j(2) - xyz_k(2))/rjk
                        drjkdzj = (xyz_j(3) - xyz_k(3))/rjk
                        drjkdxk = -1.d0*drjkdxj
                        drjkdyk = -1.d0*drjkdyj
                        drjkdzk = -1.d0*drjkdzj
                        drjkdxi = 0.d0
                        drjkdyi = 0.d0
                        drjkdzi = 0.d0
                        temp1=0.5d0*(-dsin(pi*rjk/cutoff))*(pi/cutoff)
                        dfcutjkdxj=temp1*drjkdxj
                        dfcutjkdyj=temp1*drjkdyj
                        dfcutjkdzj=temp1*drjkdzj
                        dfcutjkdxk=-1.d0*dfcutjkdxj
                        dfcutjkdyk=-1.d0*dfcutjkdyj
                        dfcutjkdzk=-1.d0*dfcutjkdzj
                        dfcutjkdxi=0.0d0
                        dfcutjkdyi=0.0d0
                        dfcutjkdzi=0.0d0
                    endif
                    f=rjk**2 - rij**2 -rik**2
                    g=-2.d0*rij*rik
                    costheta=f/g
                    !!!!  2^1-eta (1+lamda coseta_ijk)^eta 
                    !!!!  eta = 1 lamda = +1.d0
                    costheta=1.d0 + costheta
                    if (lgrad) then
                        dfdxi=-2.d0*rij*drijdxi - 2.d0*rik*drikdxi
                        dfdyi=-2.d0*rij*drijdyi - 2.d0*rik*drikdyi
                        dfdzi=-2.d0*rij*drijdzi - 2.d0*rik*drikdzi

                        dfdxj=2.d0*rjk*drjkdxj - 2.d0*rij*drijdxj
                        dfdyj=2.d0*rjk*drjkdyj - 2.d0*rij*drijdyj
                        dfdzj=2.d0*rjk*drjkdzj - 2.d0*rij*drijdzj

                        dfdxk=2.d0*rjk*drjkdxk - 2.d0*rik*drikdxk
                        dfdyk=2.d0*rjk*drjkdyk - 2.d0*rik*drikdyk
                        dfdzk=2.d0*rjk*drjkdzk - 2.d0*rik*drikdzk

                        dgdxi=-2.d0*(drijdxi*rik + rij*drikdxi)
                        dgdyi=-2.d0*(drijdyi*rik + rij*drikdyi)
                        dgdzi=-2.d0*(drijdzi*rik + rij*drikdzi)

                        dgdxj=-2.d0*drijdxj*rik
                        dgdyj=-2.d0*drijdyj*rik
                        dgdzj=-2.d0*drijdzj*rik

                        dgdxk=-2.d0*rij*drikdxk
                        dgdyk=-2.d0*rij*drikdyk
                        dgdzk=-2.d0*rij*drikdzk

                        temp1=1.d0/g**2
                        dcosthetadxi=(dfdxi*g - f*dgdxi)*temp1
                        dcosthetadyi=(dfdyi*g - f*dgdyi)*temp1
                        dcosthetadzi=(dfdzi*g - f*dgdzi)*temp1
                        dcosthetadxj=(dfdxj*g - f*dgdxj)*temp1
                        dcosthetadyj=(dfdyj*g - f*dgdyj)*temp1
                        dcosthetadzj=(dfdzj*g - f*dgdzj)*temp1
                        dcosthetadxk=(dfdxk*g - f*dgdxk)*temp1
                        dcosthetadyk=(dfdyk*g - f*dgdyk)*temp1
                        dcosthetadzk=(dfdzk*g - f*dgdzk)*temp1
                    endif
                    expxyz=dexp(-alpha*(rij**2+rik**2+rjk**2))
                    if (lgrad) then
                        temp1=-alpha*2.0d0*expxyz
                        dexpxyzdxi=(rij*drijdxi+rik*drikdxi+rjk*drjkdxi)*temp1
                        dexpxyzdyi=(rij*drijdyi+rik*drikdyi+rjk*drjkdyi)*temp1
                        dexpxyzdzi=(rij*drijdzi+rik*drikdzi+rjk*drjkdzi)*temp1
                        dexpxyzdxj=(rij*drijdxj+rik*drikdxj+rjk*drjkdxj)*temp1
                        dexpxyzdyj=(rij*drijdyj+rik*drikdyj+rjk*drjkdyj)*temp1
                        dexpxyzdzj=(rij*drijdzj+rik*drikdzj+rjk*drjkdzj)*temp1
                        dexpxyzdxk=(rij*drijdxk+rik*drikdxk+rjk*drjkdxk)*temp1
                        dexpxyzdyk=(rij*drijdyk+rik*drikdyk+rjk*drjkdyk)*temp1
                        dexpxyzdzk=(rij*drijdzk+rik*drikdzk+rjk*drjkdzk)*temp1
                    endif
                    xx(ii,i)=xx(ii,i)+costheta*expxyz*fcutij*fcutik*fcutjk
                    xx(ii + nnn,i)=xx(ii + nnn,i)+&
                    costheta*expxyz*fcutij*fcutik*fcutjk*weights_j*weights_k

                    if (lgrad) then
                        temp1=(dcosthetadxi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxi)
                        temp2=(dcosthetadxj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxj)
                        temp3=(dcosthetadxk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,1)=dxdy(ii,i,i,1)+temp1
                        dxdy(ii,i,n,1)=dxdy(ii,i,n,1)+temp2
                        dxdy(ii,i,m,1)=dxdy(ii,i,m,1)+temp3
                        dxdy(ii + nnn,i,i,1)=dxdy(ii + nnn,i,i,1)+temp4
                        dxdy(ii + nnn,i,n,1)=dxdy(ii + nnn,i,n,1)+temp5
                        dxdy(ii + nnn,i,m,1)=dxdy(ii + nnn,i,m,1)+temp6

                        strs(1,1,ii,i)=strs(1,1,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,1,ii,i)=strs(2,1,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,1,ii,i)=strs(3,1,ii,i)+deltazj*temp2+deltazk*temp3
                        strs(1,1,ii + nnn,i)=strs(1,1,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,1,ii + nnn,i)=strs(2,1,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,1,ii + nnn,i)=strs(3,1,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        ! dxxii/dy_i
                        temp1=(dcosthetadyi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyi)
                        temp2=(dcosthetadyj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyj)
                        temp3=(dcosthetadyk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,2)=dxdy(ii,i,i,2)+temp1
                        dxdy(ii,i,n,2)=dxdy(ii,i,n,2)+temp2
                        dxdy(ii,i,m,2)=dxdy(ii,i,m,2)+temp3

                        dxdy(ii + nnn,i,i,2)=dxdy(ii + nnn,i,i,2)+temp4
                        dxdy(ii + nnn,i,n,2)=dxdy(ii + nnn,i,n,2)+temp5
                        dxdy(ii + nnn,i,m,2)=dxdy(ii + nnn,i,m,2)+temp6
                        strs(1,2,ii,i)=strs(1,2,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,2,ii,i)=strs(2,2,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,2,ii,i)=strs(3,2,ii,i)+deltazj*temp2+deltazk*temp3

                        strs(1,2,ii + nnn,i)=strs(1,2,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,2,ii + nnn,i)=strs(2,2,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,2,ii + nnn,i)=strs(3,2,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        ! dxxii/dz_i
                        temp1=(dcosthetadzi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzi)
                        temp2=(dcosthetadzj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzj)
                        temp3=(dcosthetadzk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,3)=dxdy(ii,i,i,3)+temp1
                        dxdy(ii,i,n,3)=dxdy(ii,i,n,3)+temp2
                        dxdy(ii,i,m,3)=dxdy(ii,i,m,3)+temp3

                        dxdy(ii + nnn,i,i,3)=dxdy(ii + nnn,i,i,3)+temp4
                        dxdy(ii + nnn,i,n,3)=dxdy(ii + nnn,i,n,3)+temp5
                        dxdy(ii + nnn,i,m,3)=dxdy(ii + nnn,i,m,3)+temp6
                        strs(1,3,ii,i)=strs(1,3,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,3,ii,i)=strs(2,3,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,3,ii,i)=strs(3,3,ii,i)+deltazj*temp2+deltazk*temp3

                        strs(1,3,ii + nnn,i)=strs(1,3,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,3,ii + nnn,i)=strs(2,3,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,3,ii + nnn,i)=strs(3,3,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                    endif
                enddo ! k_neighbor
            enddo ! j_neighbor
!       print*, 'lllll',lllll
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
!G3 = SUM_j{exp(-alpha*(rij-rshift)**2)*fc(rij)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.3) then
        cutoff = ACSF%sf(ii)%cutoff
        rshift = ACSF%sf(ii)%alpha
        alpha = 4.d0
        do i = 1, natoms
            do i_neighbor = 1, neighbor_count(i)
                rij = neighbor(i, i_neighbor,4)
                if (rij.gt.cutoff) cycle
                xyz = neighbor(i, i_neighbor,1:3)
                weights = neighbor(i, i_neighbor, 5)
                n = int(neighbor(i, i_neighbor, 6))
                fcutij = 0.5d0 * (dcos(pi*rij/cutoff) + 1.d0)
                if (lgrad) then
                    deltaxj = -1.d0*(pos(i, 1) - xyz(1))
                    deltayj = -1.d0*(pos(i, 2) - xyz(2))
                    deltazj = -1.d0*(pos(i, 3) - xyz(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                endif
                xx(ii,i)=xx(ii,i)+dexp(-1.d0*alpha*(rij-rshift)**2)*fcutij
                xx(ii + nnn,i)=xx(ii + nnn,i)+dexp(-1.d0*alpha*(rij-rshift)**2)*fcutij*weights
                if (lgrad) then
                    temp1=-2.d0*alpha*(rij-rshift)
                    temp2=dexp(-1.d0*alpha*(rij-rshift)**2)
                    ! dxx/dx
                    dxdy(ii,i,i,1)=dxdy(ii,i,i,1)+&
                           (temp1*drijdxi*temp2*fcutij&
                          + temp2*dfcutijdxi)

                    dxdy(ii + nnn,i,i,1)=dxdy(ii + nnn,i,i,1)+&
                           (temp1*drijdxi*temp2*fcutij&
                          + temp2*dfcutijdxi)*weights
                    temp3=temp1*drijdxj*temp2*fcutij + temp2*dfcutijdxj
                    dxdy(ii,i,n,1)=dxdy(ii,i,n,1)+temp3
                    temp4 = temp3 * weights
                    dxdy(ii + nnn,i,n,1)=dxdy(ii + nnn,i,n,1)+temp4
                    strs(1,1,ii,i)=strs(1,1,ii,i)+deltaxj*temp3
                    strs(2,1,ii,i)=strs(2,1,ii,i)+deltayj*temp3
                    strs(3,1,ii,i)=strs(3,1,ii,i)+deltazj*temp3
                    strs(1,1,ii + nnn,i)=strs(1,1,ii + nnn,i)+deltaxj*temp4
                    strs(2,1,ii + nnn,i)=strs(2,1,ii + nnn,i)+deltayj*temp4
                    strs(3,1,ii + nnn,i)=strs(3,1,ii + nnn,i)+deltazj*temp4
                    ! dxx/dy
                    dxdy(ii,i,i,2)=dxdy(ii,i,i,2)+&
                           (temp1*drijdyi*temp2*fcutij&
                          + temp2*dfcutijdyi)
                    dxdy(ii + nnn,i,i,2)=dxdy(ii + nnn,i,i,2)+&
                           (temp1*drijdyi*temp2*fcutij&
                          + temp2*dfcutijdyi)*weights
                    temp3= temp1*drijdyj*temp2*fcutij + temp2*dfcutijdyj
                    dxdy(ii,i,n,2)=dxdy(ii,i,n,2)+temp3
                    temp4 = temp3 * weights
                    dxdy(ii + nnn,i,n,2)=dxdy(ii + nnn,i,n,2)+temp4
                    strs(1,2,ii,i)=strs(1,2,ii,i)+deltaxj*temp3
                    strs(2,2,ii,i)=strs(2,2,ii,i)+deltayj*temp3
                    strs(3,2,ii,i)=strs(3,2,ii,i)+deltazj*temp3

                    strs(1,2,ii + nnn,i)=strs(1,2,ii + nnn,i)+deltaxj*temp4
                    strs(2,2,ii + nnn,i)=strs(2,2,ii + nnn,i)+deltayj*temp4
                    strs(3,2,ii + nnn,i)=strs(3,2,ii + nnn,i)+deltazj*temp4
                    ! dxx/dz
                    dxdy(ii,i,i,3)=dxdy(ii,i,i,3)+&
                           (temp1*drijdzi*temp2*fcutij&
                          + temp2*dfcutijdzi)
                    dxdy(ii + nnn,i,i,3)=dxdy(ii + nnn,i,i,3)+&
                           (temp1*drijdzi*temp2*fcutij&
                          + temp2*dfcutijdzi)*weights
                    temp3=temp1*drijdzj*temp2*fcutij + temp2*dfcutijdzj
                    dxdy(ii,i,n,3)=dxdy(ii,i,n,3)+temp3
                    temp4 = temp3 * weights
                    dxdy(ii + nnn,i,n,3)=dxdy(ii + nnn,i,n,3)+temp4
                    strs(1,3,ii,i)=strs(1,3,ii,i)+deltaxj*temp3
                    strs(2,3,ii,i)=strs(2,3,ii,i)+deltayj*temp3
                    strs(3,3,ii,i)=strs(3,3,ii,i)+deltazj*temp3

                    strs(1,3,ii + nnn,i)=strs(1,3,ii + nnn,i)+deltaxj*temp4
                    strs(2,3,ii + nnn,i)=strs(2,3,ii + nnn,i)+deltayj*temp4
                    strs(3,3,ii + nnn,i)=strs(3,3,ii + nnn,i)+deltazj*temp4
                endif
            enddo ! i_neighbor
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
! lamda = -1.d0
! eta = 1
! G2 = SUM_jk{(1+lamda*costheta_ijk)^eta*
! exp(-alpha*(rij**2+rik**2+rjk**2))*fc(rij)*fc(rik)*fc(rjk)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.4) then
        cutoff = ACSF%sf(ii)%cutoff
        alpha = ACSF%sf(ii)%alpha
        do i = 1, natoms
            do j_neighbor = 1, neighbor_count(i)
                rij = neighbor(i, j_neighbor,4)
                if (rij.gt.cutoff) cycle
                xyz_j = neighbor(i, j_neighbor,1:3)
                weights_j = neighbor(i, j_neighbor, 5)
                n = int(neighbor(i, j_neighbor, 6))
                fcutij=0.5d0*(dcos(pi*rij/cutoff)+1.d0)
                if (lgrad) then
                    deltaxj = -1.d0*(pos(i, 1) - xyz_j(1))
                    deltayj = -1.d0*(pos(i, 2) - xyz_j(2))
                    deltazj = -1.d0*(pos(i, 3) - xyz_j(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    drijdxk = 0.d0
                    drijdyk = 0.d0
                    drijdzk = 0.d0
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    dfcutijdxk=0.0d0
                    dfcutijdyk=0.0d0
                    dfcutijdzk=0.0d0
                endif
                do k_neighbor = 1, neighbor_count(i)
                    if (k_neighbor <= j_neighbor) cycle
                    rik = neighbor(i,k_neighbor,4)
                    if (rik.gt.cutoff) cycle
                    xyz_k = neighbor(i, k_neighbor,1:3)
                    weights_k = neighbor(i, k_neighbor,5)
                    m = int(neighbor(i, k_neighbor,6))
                    fcutik=0.5d0*(dcos(pi*rik/cutoff)+1.d0)

                    if (lgrad) then
                        deltaxk = -1.d0*(pos(i, 1) - xyz_k(1))
                        deltayk = -1.d0*(pos(i, 2) - xyz_k(2))
                        deltazk = -1.d0*(pos(i, 3) - xyz_k(3))
                        drikdxi = -deltaxk/rik
                        drikdyi = -deltayk/rik
                        drikdzi = -deltazk/rik
                        drikdxk = -1.d0*drikdxi
                        drikdyk = -1.d0*drikdyi
                        drikdzk = -1.d0*drikdzi
                        drikdxj = 0.d0
                        drikdyj = 0.d0
                        drikdzj = 0.d0
                        temp1=0.5d0*(-dsin(pi*rik/cutoff))*(pi/cutoff)
                        dfcutikdxi=temp1*drikdxi
                        dfcutikdyi=temp1*drikdyi
                        dfcutikdzi=temp1*drikdzi
                        dfcutikdxj=0.0d0
                        dfcutikdyj=0.0d0
                        dfcutikdzj=0.0d0
                        dfcutikdxk=-1.d0*dfcutikdxi
                        dfcutikdyk=-1.d0*dfcutikdyi
                        dfcutikdzk=-1.d0*dfcutikdzi
                    endif
                    rjk = (xyz_j(1) - xyz_k(1))**2 + (xyz_j(2) - xyz_k(2))**2 + (xyz_j(3) - xyz_k(3))**2
                    rjk = dsqrt(rjk)

                    if (rjk.gt.cutoff) cycle  ! Be careful STUPID!!!
                    if (rjk < Rmin) then
                        print*, 'Rjk', rjk,' smaller than Rmin'
                    !    stop
                    endif
                    fcutjk=0.5d0*(dcos(pi*rjk/cutoff)+1.d0)
                    if (lgrad) then
                        drjkdxj = (xyz_j(1) - xyz_k(1))/rjk
                        drjkdyj = (xyz_j(2) - xyz_k(2))/rjk
                        drjkdzj = (xyz_j(3) - xyz_k(3))/rjk
                        drjkdxk = -1.d0*drjkdxj
                        drjkdyk = -1.d0*drjkdyj
                        drjkdzk = -1.d0*drjkdzj
                        drjkdxi = 0.d0
                        drjkdyi = 0.d0
                        drjkdzi = 0.d0
                        temp1=0.5d0*(-dsin(pi*rjk/cutoff))*(pi/cutoff)
                        dfcutjkdxj=temp1*drjkdxj
                        dfcutjkdyj=temp1*drjkdyj
                        dfcutjkdzj=temp1*drjkdzj
                        dfcutjkdxk=-1.d0*dfcutjkdxj
                        dfcutjkdyk=-1.d0*dfcutjkdyj
                        dfcutjkdzk=-1.d0*dfcutjkdzj
                        dfcutjkdxi=0.0d0
                        dfcutjkdyi=0.0d0
                        dfcutjkdzi=0.0d0
                    endif

                    f=rjk**2 - rij**2 -rik**2
                    g=-2.d0*rij*rik
                    costheta=f/g
                    costheta=1.d0 - costheta  ! avoid negative values
                    if (lgrad) then
                        dfdxi=-2.d0*rij*drijdxi - 2.d0*rik*drikdxi
                        dfdyi=-2.d0*rij*drijdyi - 2.d0*rik*drikdyi
                        dfdzi=-2.d0*rij*drijdzi - 2.d0*rik*drikdzi

                        dfdxj=2.d0*rjk*drjkdxj - 2.d0*rij*drijdxj
                        dfdyj=2.d0*rjk*drjkdyj - 2.d0*rij*drijdyj
                        dfdzj=2.d0*rjk*drjkdzj - 2.d0*rij*drijdzj

                        dfdxk=2.d0*rjk*drjkdxk - 2.d0*rik*drikdxk
                        dfdyk=2.d0*rjk*drjkdyk - 2.d0*rik*drikdyk
                        dfdzk=2.d0*rjk*drjkdzk - 2.d0*rik*drikdzk

                        dgdxi=-2.d0*(drijdxi*rik + rij*drikdxi)
                        dgdyi=-2.d0*(drijdyi*rik + rij*drikdyi)
                        dgdzi=-2.d0*(drijdzi*rik + rij*drikdzi)

                        dgdxj=-2.d0*drijdxj*rik
                        dgdyj=-2.d0*drijdyj*rik
                        dgdzj=-2.d0*drijdzj*rik

                        dgdxk=-2.d0*rij*drikdxk
                        dgdyk=-2.d0*rij*drikdyk
                        dgdzk=-2.d0*rij*drikdzk

                        temp1=1.d0/g**2
                        !!!! Be careful costheta = 1.d0 - costheta 2019.07.25
                        dcosthetadxi=-1.d0 * (dfdxi*g - f*dgdxi)*temp1  
                        dcosthetadyi=-1.d0 * (dfdyi*g - f*dgdyi)*temp1 
                        dcosthetadzi=-1.d0 * (dfdzi*g - f*dgdzi)*temp1 
                        dcosthetadxj=-1.d0 * (dfdxj*g - f*dgdxj)*temp1 
                        dcosthetadyj=-1.d0 * (dfdyj*g - f*dgdyj)*temp1 
                        dcosthetadzj=-1.d0 * (dfdzj*g - f*dgdzj)*temp1 
                        dcosthetadxk=-1.d0 * (dfdxk*g - f*dgdxk)*temp1 
                        dcosthetadyk=-1.d0 * (dfdyk*g - f*dgdyk)*temp1 
                        dcosthetadzk=-1.d0 * (dfdzk*g - f*dgdzk)*temp1 
                    endif

                    expxyz=dexp(-alpha*(rij**2+rik**2+rjk**2))

                    xx(ii,i)=xx(ii,i)+costheta*expxyz*fcutij*fcutik*fcutjk
                    xx(ii + nnn,i)=xx(ii + nnn,i)+&
                    costheta*expxyz*fcutij*fcutik*fcutjk*weights_j*weights_k
                    if (lgrad) then
                        temp1=-alpha*2.0d0*expxyz
                        dexpxyzdxi=(rij*drijdxi+rik*drikdxi+rjk*drjkdxi)*temp1
                        dexpxyzdyi=(rij*drijdyi+rik*drikdyi+rjk*drjkdyi)*temp1
                        dexpxyzdzi=(rij*drijdzi+rik*drikdzi+rjk*drjkdzi)*temp1
                        dexpxyzdxj=(rij*drijdxj+rik*drikdxj+rjk*drjkdxj)*temp1
                        dexpxyzdyj=(rij*drijdyj+rik*drikdyj+rjk*drjkdyj)*temp1
                        dexpxyzdzj=(rij*drijdzj+rik*drikdzj+rjk*drjkdzj)*temp1
                        dexpxyzdxk=(rij*drijdxk+rik*drikdxk+rjk*drjkdxk)*temp1
                        dexpxyzdyk=(rij*drijdyk+rik*drikdyk+rjk*drjkdyk)*temp1
                        dexpxyzdzk=(rij*drijdzk+rik*drikdzk+rjk*drjkdzk)*temp1
                        temp1=(dcosthetadxi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxi)
                        temp2=(dcosthetadxj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxj)
                        temp3=(dcosthetadxk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdxk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdxk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdxk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdxk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,1)=dxdy(ii,i,i,1)+temp1
                        dxdy(ii,i,n,1)=dxdy(ii,i,n,1)+temp2
                        dxdy(ii,i,m,1)=dxdy(ii,i,m,1)+temp3
                        dxdy(ii + nnn,i,i,1)=dxdy(ii + nnn,i,i,1)+temp4
                        dxdy(ii + nnn,i,n,1)=dxdy(ii + nnn,i,n,1)+temp5
                        dxdy(ii + nnn,i,m,1)=dxdy(ii + nnn,i,m,1)+temp6

                        strs(1,1,ii,i)=strs(1,1,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,1,ii,i)=strs(2,1,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,1,ii,i)=strs(3,1,ii,i)+deltazj*temp2+deltazk*temp3
                        strs(1,1,ii + nnn,i)=strs(1,1,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,1,ii + nnn,i)=strs(2,1,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,1,ii + nnn,i)=strs(3,1,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        ! dxxii/dy_i
                        temp1=(dcosthetadyi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyi)
                        temp2=(dcosthetadyj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyj)
                        temp3=(dcosthetadyk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdyk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdyk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdyk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdyk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,2)=dxdy(ii,i,i,2)+temp1
                        dxdy(ii,i,n,2)=dxdy(ii,i,n,2)+temp2
                        dxdy(ii,i,m,2)=dxdy(ii,i,m,2)+temp3

                        dxdy(ii + nnn,i,i,2)=dxdy(ii + nnn,i,i,2)+temp4
                        dxdy(ii + nnn,i,n,2)=dxdy(ii + nnn,i,n,2)+temp5
                        dxdy(ii + nnn,i,m,2)=dxdy(ii + nnn,i,m,2)+temp6
                        strs(1,2,ii,i)=strs(1,2,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,2,ii,i)=strs(2,2,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,2,ii,i)=strs(3,2,ii,i)+deltazj*temp2+deltazk*temp3

                        strs(1,2,ii + nnn,i)=strs(1,2,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,2,ii + nnn,i)=strs(2,2,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,2,ii + nnn,i)=strs(3,2,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        ! dxxii/dz_i
                        temp1=(dcosthetadzi*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzi*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzi*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzi*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzi)
                        temp2=(dcosthetadzj*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzj*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzj*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzj*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzj)
                        temp3=(dcosthetadzk*expxyz*fcutij*fcutik*fcutjk&
                              +costheta*dexpxyzdzk*fcutij*fcutik*fcutjk&
                              +costheta*expxyz*dfcutijdzk*fcutik*fcutjk&
                              +costheta*expxyz*fcutij*dfcutikdzk*fcutjk&
                              +costheta*expxyz*fcutij*fcutik*dfcutjkdzk)
                        temp4 = temp1 * weights_j * weights_k
                        temp5 = temp2 * weights_j * weights_k
                        temp6 = temp3 * weights_j * weights_k
                        dxdy(ii,i,i,3)=dxdy(ii,i,i,3)+temp1
                        dxdy(ii,i,n,3)=dxdy(ii,i,n,3)+temp2
                        dxdy(ii,i,m,3)=dxdy(ii,i,m,3)+temp3

                        dxdy(ii + nnn,i,i,3)=dxdy(ii + nnn,i,i,3)+temp4
                        dxdy(ii + nnn,i,n,3)=dxdy(ii + nnn,i,n,3)+temp5
                        dxdy(ii + nnn,i,m,3)=dxdy(ii + nnn,i,m,3)+temp6
                        strs(1,3,ii,i)=strs(1,3,ii,i)+deltaxj*temp2+deltaxk*temp3
                        strs(2,3,ii,i)=strs(2,3,ii,i)+deltayj*temp2+deltayk*temp3
                        strs(3,3,ii,i)=strs(3,3,ii,i)+deltazj*temp2+deltazk*temp3

                        strs(1,3,ii + nnn,i)=strs(1,3,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                        strs(2,3,ii + nnn,i)=strs(2,3,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                        strs(3,3,ii + nnn,i)=strs(3,3,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                    endif ! lgrad
                enddo ! k_neighbor
            enddo ! j_neighbor
        enddo ! i
    else
        print *, 'Unknown function type',ii, ACSF%sf(ii)%ntype
    endif
enddo  ! types
END SUBROUTINE

SUBROUTINE  write_array_2dim(n,m, a,name)
REAL(8),intent(in),dimension(n,m)       :: a
character(*),intent(in)                :: name
integer                                  :: i,j
open(2244,file=trim(adjustl(name)))
do i = 1, n
    do j = 1, m
        write(2244,'(F20.10,$)') a(i,j)
    enddo
    write(2244,*)
enddo
close(2244)
END SUBROUTINE



