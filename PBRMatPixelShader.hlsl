#include <PBRHeader.hlsli>

Texture2D albedoSRV : register(t0);
Texture2D normalSRV : register(t1);
Texture2D metallicSRV : register(t2);
Texture2D roughSRV : register(t3);

SamplerState basicSampler : register(s0);

cbuffer ExternalData : register(b0) {
	/*float3 albedo;
	float metallic;
	float roughness;*/
	float ao;

	float3 lightPos1;
	float3 lightPos2;
	float3 lightPos3;
	float3 lightPos4;
	float3 lightCol;

	float3 camPos;
};

void CalcRadiance(VertexToPixel input, float3 viewDir, float3 normalVec, float3 albedo, float roughness, float metallic, float3 lightPos, float3 lightCol, float3 F0, out float3 rad)
{
	static const float PI = 3.14159265359;

	//calculate light radiance
	float3 lightDir = normalize(lightPos - input.worldPos);
	float3 halfwayVec = normalize(viewDir + lightDir);
	float distance = length(lightPos - input.worldPos);
	float attenuation = 1.0f / (distance * distance);
	float3 radiance = lightCol * attenuation;

	//Cook-Torrance BRDF
	float D = NormalDistributionGGXTR(normalVec, halfwayVec, roughness);
	float G = GeometrySmith(normalVec, viewDir, lightDir, roughness);
	float3 F = FresnelSchlick(max(dot(halfwayVec, viewDir), 0.0f), F0);

	float3 kS = F;
	float3 kD = float3(1.0f, 1.0f, 1.0f) - kS;
	kD *= 1.0 - metallic;

	float3 nom = D * G * F;
	float denom = 4 * max(dot(normalVec, viewDir), 0.0f) * max(dot(normalVec, lightDir), 0.0) + 0.001f; // 0.001f just in case product is 0
	float3 specular = nom / denom;

	//Add to outgoing radiance Lo
	float NdotL = max(dot(normalVec, lightDir), 0.0f);
	rad = (((kD * albedo / PI) + specular) * radiance * NdotL);
}

float4 main(VertexToPixel input) : SV_TARGET
{
	//static const float PI = 3.14159265359;
	/*float3 albedo;
	float metallic;
	float roughness;*/
	//Albedo
	float3 albedo = pow(albedoSRV.Sample(basicSampler, input.uv).rgb, 2.2f);

	//Normal
	input.normal = normalize(input.normal);
	input.tangent = normalize(input.tangent);
	
	float3 normalFromMap = normalSRV.Sample(basicSampler, input.uv).xyz * 2 - 1;

	float3 N = input.normal;
	float3 T = normalize(input.tangent - N * dot(input.tangent, N));
	float3 B = cross(T, N);

	float3x3 TBN = float3x3(T, B, N);
	input.normal = normalize(mul(normalFromMap, TBN));
	
	float3 normalVec = input.normal;
	
	//Metallic
	float metallic = metallicSRV.Sample(basicSampler, input.uv).r;

	//Rough
	float rough = roughSRV.Sample(basicSampler, input.uv).r;
	
	float3 viewDir = normalize(camPos - input.worldPos);
	
	float3 F0 = float3(0.04f, 0.04f, 0.04f);
	F0 = lerp(F0, albedo, metallic);

	float3 rad = float3(0.0f, 0.0f, 0.0f);
	//reflectance equation
	float3 Lo = float3(0.0f, 0.0f, 0.0f);

	CalcRadiance(input, viewDir, normalVec, albedo, rough, metallic, lightPos1, lightCol, F0, rad);
	Lo += rad;

	CalcRadiance(input, viewDir, normalVec, albedo, rough, metallic, lightPos2, lightCol, F0, rad);
	Lo += rad;

	CalcRadiance(input, viewDir, normalVec, albedo, rough, metallic, lightPos3, lightCol, F0, rad);
	Lo += rad;

	CalcRadiance(input, viewDir, normalVec, albedo, rough, metallic, lightPos4, lightCol, F0, rad);
	Lo += rad;

	float3 ambient = float3(0.03f, 0.03f, 0.03f) * albedo * ao;
	float3 color = ambient + Lo;


	color = color / (color + float3(1.0f, 1.0f, 1.0f));
	color = pow(color, float3(1.0f / 2.2f, 1.0f / 2.2f, 1.0f / 2.2f));

	return float4(color, 1.0f);
}