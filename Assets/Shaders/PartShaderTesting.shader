Shader "PartShaderTesting"
{
	Properties
	{
		_Colour ("Color", Color) = (1, 1, 1, 1)
		_MetallicColour ("Colour for bare metal surfaces", Color) = (0.6, 0.6, 0.6, 1)

		_DetailStrength ("Detail strength", Range(0, 2.5)) = 1

		_ParallaxStrength ("Parallax strength", Range(0, 1)) = 1
		_MinSamples ("Minimum number of parallax samples", Int) = 8
		_MaxSamples ("Maximum number of parallax samples", Int) = 64

		_BaseMetalness ("Base metalness", Range(0, 1)) = 0
		_BaseSmoothness ("Base smoothness", Range(0, 1)) = 0

		_DetailTexture ("Detail Texture", 2D) = "" {}
		_NormalMapTexture ("Normal Map Texture", 2D) = "" {}
		_MRAOTexture ("Metalness, roughness, ambient occlusion, mask texture", 2D) = "" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows vertex:vert
		#pragma target 3.5

		#include "POM.cginc"

		float4 _Colour;
		float4 _MetallicColour;

		float _DetailStrength;
		float _OcclusionStrength;

		float _ParallaxStrength;
		float _MinSamples;
		float _MaxSamples;

		float _BaseMetalness;
		float _BaseSmoothness;

		sampler2D _DetailTexture;
		sampler2D _NormalMapTexture;
		sampler2D _MRAOTexture;
		
		struct v2f
		{
			float4 vertex : POSITION;
			float3 normal : NORMAL;
			float4 tangent : TANGENT;
			float4 texcoord : TEXCOORD0;
			float4 texcoord1 : TEXCOORD1;
			float4 texcoord2 : TEXCOORD2;
		};

		struct Input
		{
			float2 texcoord;
			float4 posWorld;
			float3 tSpace0;
			float3 tSpace1;
			float3 tSpace2;
		};

		void vert(inout v2f v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input,o);

			o.posWorld = mul(unity_ObjectToWorld, v.vertex);
			fixed3 worldNormal = mul(v.normal.xyz, (float3x3)unity_WorldToObject);
			fixed3 worldTangent =  normalize(mul((float3x3)unity_ObjectToWorld,v.tangent.xyz ));
			fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
			o.tSpace0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
			o.tSpace1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
			o.tSpace2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);	

			o.texcoord = v.texcoord;
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float4 colour = _Colour;
			float2 texcoord = IN.texcoord;

			fixed3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - IN.posWorld.xyz);
			fixed3 viewDir = IN.tSpace0.xyz * worldViewDir.x + IN.tSpace1.xyz * worldViewDir.y  + IN.tSpace2.xyz * worldViewDir.z;

			ParallaxOcclusionMapping(
				_MRAOTexture, _ParallaxStrength,
				_MinSamples, _MaxSamples,
				viewDir,
				texcoord
			);

			float2 texDetail = tex2D(_DetailTexture, texcoord).rg;
			colour.rgb += (texDetail.r - 0.5019608) * _DetailStrength;
			colour.rgb = saturate(colour.rgb);

			float4 texNormal = tex2D(_NormalMapTexture, texcoord);
			fixed3 localNormal = UnpackNormal(texNormal);
			localNormal.xy *= _DetailStrength;
			localNormal.z += 0.0001;

			float4 metalnessRoughnessAOMask = tex2D(_MRAOTexture, texcoord);
			metalnessRoughnessAOMask = lerp(
				float4(_BaseMetalness, 1.f - _BaseSmoothness, 1.f, 1.f),
				metalnessRoughnessAOMask,
				saturate(_DetailStrength)
			);

			o.Albedo = lerp(_MetallicColour, colour, metalnessRoughnessAOMask.a).rgb;
			o.Normal = localNormal;
			o.Metallic = metalnessRoughnessAOMask.r;
			o.Smoothness = 1.f - metalnessRoughnessAOMask.g;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
