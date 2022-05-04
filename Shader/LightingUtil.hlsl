#define MaxLights 16

struct Light
{
    float3 Strength;
    float FalloffStart;
    float3 Direction;
    float FalloffEnd;
    float3 Position;
    float SpotPower;
};

struct Material
{
    float4 DiffuseAlbedo;
    float3 FresnelR0;
    float Shininess;
};

float CalAttenuation(float d, float falloffStart, float falloffEnd)
{
    return saturate((falloffEnd - d) / (falloffEnd - falloffStart));
}

float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
{
    float cosIncidentAngle = saturate(dot(normal, lightVec));
    float f0 = 1 - cosIncidentAngle;
    float3 reflectPercent = R0 + (1.0f - R0) * pow(f0, 5);
    
    return reflectPercent;
}

float3 BlinePhong(float3 lightStrength, float3 lightVec, float3 normal, 
                float3 toEye, Material mat)
{
    float m = mat.Shininess * 256.0f;
    float3 halfVec = normalize(toEye + lightVec);
    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, normal, lightVec);
    float roughnessFactor = (m + 8.0f) * pow(max(dot(normal, halfVec), 0.0f), m) / 8.0f;

    float3 specAlbedo = roughnessFactor * fresnelFactor;
    
    // Our spec formula goes outside [0,1] range,
    // but we are doing LDR rendering. So scale it down a bit.
    specAlbedo = specAlbedo / (specAlbedo + 1.0f);
    
    return (mat.DiffuseAlbedo.rgb + specAlbedo) * lightStrength;
}

float3 ComputeDirectionalLight(Light L,Material mat, float3 normal, float3 toEyes)
{
    float3 lightVec = -L.Direction;
    
    float ndotl = max(dot(normal, lightVec), 0.0f);
    float3 lightStrength = L.Strength * ndotl;
    
    return BlinePhong(lightStrength, lightVec, normal, toEyes, mat);
}

float3 ComputePointLight(Light L, Material mat, float3 pos, float3 normal, float3 toEyes)
{
    float3 lightVec = L.Position - pos;
    
    float d = length(lightVec);
    
    if(d > L.FalloffEnd)
        return 0.0f;
    
    lightVec /= d;
    
    float ndotl = max(dot(normal, lightVec), 0.0f);
    float atten = CalAttenuation(d, L.FalloffStart, L.FalloffEnd);
    
    float3 lightStrength = L.Strength * ndotl * atten;
    
    return BlinePhong(lightStrength, lightVec, normal, toEyes, mat);
}

float3 ComputeSpotLight(Light L,Material mat,float3 pos,float3 normal, float3 toEye)
{
    float3 lightVec = L.Position - pos;
    
    float d = length(lightVec);
    
    if(d>L.FalloffEnd)
    {
        return 0.0f;
    }
    
    lightVec /= d;
    
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float atten = CalAttenuation(d, L.FalloffStart, L.FalloffEnd);
    
    float spotFactor = pow(max(dot(-lightVec, L.Direction), 0.0f), L.SpotPower);
    float3 lightStrength = L.Strength * atten * spotFactor;
    
    return BlinePhong(lightStrength, lightVec, normal, toEye, mat);
}

float4 ComputeLighting(Light gLights[MaxLights],Material mat,
                        float3 pos, float3 normal, float3 toEye,
                        float3 shadowFactor)
{
    float3 result = 0.0f;
    
    int i = 0;
    
#if (NUM_DIR_LIGHTS > 0)
    for(i=0;i<NUM_DIR_LIGHTS;++i)
    {
        result+=shadowFactor[i]*ComputeDirectionalLight(gLights[i],mat,normal,toEye);
    }
#endif
    
#if (NUM_POINT_LIGHTS > 0)
    for(i=NUM_DIR_LIGHTS; i <NUM_DIR_LIGHTS+NUM_POINT_LIGHTS; ++i )
    {
        result+=ComputePointLight(gLights[i],mat,pos,normal,toEye);
    }
#endif

#if (NUM_SPOT_LIGHTS > 0)
    for(i=NUM_DIR_LIGHTS+NUM_POINT_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS + NUM_SPOT_LIGHTS; ++i)
    {
        result +=ComputeSpotLight(gLights[i],mat,pos,normal,toEye);
    }
#endif

    return float4(result, 0.0f);
}
