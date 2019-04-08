# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/Materials.jl/blob/master/LICENSE

mutable struct IdealPlastic <: AbstractMaterial
    # Material parameters
    youngs_modulus :: Float64
    poissons_ratio :: Float64
    yield_stress :: Float64
    # Internal state variables
    plastic_strain :: Vector{Float64}
    dplastic_strain :: Vector{Float64}
    plastic_multiplier :: Float64
    dplastic_multiplier :: Float64
    # Other parameters
    use_ad :: Bool
end

function IdealPlastic()
    youngs_modulus = 0.0
    poissons_ratio = 0.0
    yield_stress = 0.0
    plastic_strain = zeros(6)
    dplastic_strain = zeros(6)
    plastic_multiplier = 0.0
    dplastic_multiplier = 0.0
    use_ad = false
    return IdealPlastic(youngs_modulus, poissons_ratio, yield_stress,
                        plastic_strain, dplastic_strain, plastic_multiplier,
                        dplastic_multiplier, use_ad)
end

function integrate_material!(material::Material{IdealPlastic})
    mat = material.properties

    E = mat.youngs_modulus
    nu = mat.poissons_ratio
    mu = E/(2.0*(1.0+nu))
    lambda = E*nu/((1.0+nu)*(1.0-2.0*nu))

    stress = material.stress
    strain = material.strain
    dstress = material.dstress
    dstrain = material.dstrain
    D = material.jacobian

    fill!(D, 0.0)
    D[1,1] = D[2,2] = D[3,3] = 2.0*mu + lambda
    D[4,4] = D[5,5] = D[6,6] = mu
    D[1,2] = D[2,1] = D[2,3] = D[3,2] = D[1,3] = D[3,1] = lambda

    dstress[:] .= D*dstrain
    stress_tr = stress + dstress
    s11, s22, s33, s12, s23, s31 = stress_tr
    stress_v = sqrt(1/2*((s11-s22)^2 + (s22-s33)^2 + (s33-s11)^2 + 6*(s12^2+s23^2+s31^2)))
    if stress_v <= mat.yield_stress
        fill!(mat.dplastic_strain, 0.0)
        mat.dplastic_multiplier = 0.0
        return nothing
    else
        stress_h = 1.0/3.0*sum(stress_tr[1:3])
        stress_dev = stress_tr - stress_h*[1.0, 1.0, 1.0, 0.0, 0.0, 0.0]
        n = 3.0/2.0*stress_dev/stress_v
        n[4:end] .*= 2.0
        mat.dplastic_multiplier = 1.0/(3.0*mu)*(stress_v - mat.yield_stress)
        mat.dplastic_strain = mat.dplastic_multiplier*n
        dstress[:] .= D*(dstrain - mat.dplastic_strain)
        D[:,:] .-= (D*n*n'*D) / (n'*D*n)
        return nothing
    end
    return nothing
end
