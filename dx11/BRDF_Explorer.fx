
#define PI 3.14159265359

cbuffer cbPerDraw : register(b0)
{
	float4x4 tV : VIEW;
	float4x4 tVP : LAYERVIEWPROJECTION;
};

cbuffer cbPerObj : register(b1)
{
	float4x4 tW : WORLD;
	float4x4 tWV : WORLDVIEW;
	float4x4 tWIT : WORLDLAYERINVERSETRANSPOSE;
	float4 cAmb <bool color=true; string uiname="Object color";>
		= { 1.0f, 1.0f, 1.0f, 1.0f };
	float roughness = 0.5f;
};

struct DirectionalLight
{
	float3 direction;
	float3 colour;
};

StructuredBuffer<DirectionalLight> lights;

struct VS_IN
{
	float4 pos : POSITION;
	float4 normal : NORMAL;
};

struct PS_IN
{
	float4 pos : SV_Position;
	float3 normal : TEXCOORD0;
	float3 viewDir : TEXCOORD1;
};

PS_IN VS(VS_IN input)
{
	PS_IN output;
	
	output.pos = mul(input.pos, mul(tW, tVP));
	output.normal = normalize(mul(mul(input.normal.xyz, (float3x3)tWIT), (float3x3)tV).xyz);
	output.viewDir = -normalize(mul(input.pos, tWV).xyz);
	
	return output;
}

float4 PS_Lambert(PS_IN input): SV_Target
{
	float3 colour = 0.0;
	
	uint count, stride;
	lights.GetDimensions(count, stride);
	
	for (uint i = 0; i < count; i++) {
		float3 lightDir = normalize(mul(float4(lights[i].direction, 0.0), tV).xyz);
		float diffuse = saturate(dot(normalize(input.normal), lightDir));
		
		colour += diffuse * cAmb.rgb;
	}
	
	return float4(colour, 1.0);
}

float4 PS_Burley(PS_IN input): SV_Target
{
	float3 colour = 0.0;
	float3 normal = normalize(input.normal);
	
	uint count, stride;
	lights.GetDimensions(count, stride);
	
	for (uint i = 0; i < count; i++) {
		float3 l = normalize(mul(float4(lights[i].direction, 0.0), tV).xyz);
		float3 h = normalize(input.viewDir + l);
		float3 d = normalize(l - h);
		
		float LoH = saturate(dot(l, h));
		float NoL = saturate(dot(normal, l));
		float NoV = saturate(dot(normal, input.viewDir));

		float f90 = 0.5 + 2.0 * (LoH * LoH) * (roughness * roughness);
		float fre1 = 1.0f + (f90 - 1.0f) * pow(1.0f - NoL, 5.0f);
		float fre2 = 1.0f + (f90 - 1.0f) * pow(1.0f - NoV, 5.0f);
		
		float diffuse = (1.0 / PI) * fre1 * fre2;
		colour += diffuse * cAmb.rgb;
	}
	
	return float4(colour, 1.0);
}

float4 PS_Minnaert(PS_IN input): SV_Target
{
	float3 colour = 0.0;
	float3 normal = normalize(input.normal);
	
	uint count, stride;
	lights.GetDimensions(count, stride);
	
	for (uint i = 0; i < count; i++) {
		float3 l = normalize(mul(float4(lights[i].direction, 0.0), tV).xyz);
		float NoL = saturate(dot(normal, l));
		float NoV = saturate(dot(normal, input.viewDir));
		
		float diffuse = saturate(NoL * pow(NoL * NoV, roughness));
		
		colour += diffuse * cAmb.rgb;
	}
	
	return float4(colour, 1.0);
}

float4 PS_Phong(PS_IN input): SV_Target
{
	float3 colour = 0.0;
	float3 normal = normalize(input.normal);
	
	uint count, stride;
	lights.GetDimensions(count, stride);
	
	for (uint i = 0; i < count; i++) {
		float3 l = normalize(mul(float4(lights[i].direction, 0.0), tV).xyz);
		float3 h = normalize(input.viewDir + l);
		
		float NoL = saturate(dot(normal, l));
		float NoH = saturate(dot(normal, h));
		float3 Fd = cAmb.rgb * NoL;
		
		float spec = pow(NoH, 64.0);
		float3 Fs = float3(1.0, 1.0, 1.0) * spec;
		
		colour += Fd + Fs;
	}
	
	return float4(colour, 1.0);
}

technique10 Lambert
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS_Lambert()));
	}
}

technique10 Burley
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS_Burley()));
	}
}

technique10 Minnaert
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS_Minnaert()));
	}
}

technique10 Phong
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS_Phong()));
	}
}