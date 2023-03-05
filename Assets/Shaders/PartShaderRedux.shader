Shader "PartShaderRedux"
{
	Properties
	{
		[Space(20)] [Header(Base Pass Config)]
		[Enum(UnityEngine.Rendering.BlendMode)] _BaseBlendModeSource ("_BaseBlendModeSource", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _BaseBlendModeDestination ("_BaseBlendModeDestination", Float) = 0
		[Enum(Off,0,On,1)] _BaseZWrite ("ZWrite", Float) = 1

		[Space(20)] [Header(Forward Pass Config)]
		[Enum(UnityEngine.Rendering.BlendMode)] _ForwardBlendModeSource ("_ForwardBlendModeSource", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _ForwardBlendModeDestination ("_ForwardBlendModeDestination", Float) = 1
		[Enum(Off,0,On,1)] _ForwardZWrite ("ZWrite", Float) = 0

		[Space(20)] [Header(Textures)]
		_DetailTextures ("Detail Textures", 2DArray) = "" {}
		_NormalMapTextures ("Normal Maps Textures", 2DArray) = "" {}
		_MRAOTextures ("Metalness, roughness, ambient occlusion textures", 2DArray) = "" {}
		_DecalTexture ("Decal Texture", 2D) = "black" {}
		_DecalTextureMaterialIds ("Decal Materials", Vector) = (0,0,1,1)
		_UseDecalTexture ("Use Decal Texture", Float) = 0

		[Space(20)] [Header(Texture Options)]
		[KeywordEnum(OFF, ON)] DETAIL_TEXTURES ("Detail Textures", Float) = 0
		[KeywordEnum(OFF, ON)] NORMAL_MAPS ("Normal Maps", Float) = 0

		[Space(20)] [Header(Scene Variant)]
		[KeywordEnum(OTHER, FLIGHT)] SCENE ("Scene", Float) = 0

		[Space(20)] [Header(Rim Shading Options)]
		[KeywordEnum(OFF, ON)] RIMSHADE ("Rim Shading", Float) = 0
		_Color ("Color", Vector) = (1,1,1,1)
		_MinPower ("Min Power", Range(0, 1)) = 0.1
		_MaxPower ("Max Power", Range(0, 1)) = 1

		[Space(20)] [Header(Atmosphere Options)]
		[KeywordEnum(None, LOW, HIGH)] OBJECT_ATMOSPHERE ("Atmosphere Quality", Float) = 0

		[Space(20)] [Header(Mask Render)]
		_ReentryMaskBaseStrength ("Reentry Mask Base Strength", Range(0, 10)) = 2
		_ReentryMaskWrapAmount ("Reentry Mask WrapAmount", Range(-1, 0)) = -1
		_VaporMaskBaseStrength ("Vapor Mask Base Strength", Range(0, 10)) = 1
		_VaporMaskWrapAmount ("Vapor Mask WrapAmount", Range(-1, 0)) = -0.2
		_MainTex ("Main Texture (Unused)", 2D) = "black" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows vertex:vert
		#pragma target 3.5

		// These have been calibrated using the test material
		#define PARALLAX_STRENGTH 0.02
		#define MIN_SAMPLES 32
		#define MAX_SAMPLES 64

		UNITY_DECLARE_TEX2DARRAY(_DetailTextures);
		UNITY_DECLARE_TEX2DARRAY(_NormalMapTextures);
		UNITY_DECLARE_TEX2DARRAY(_MRAOTextures);
		UNITY_DECLARE_TEX2DARRAY(_HeightTextures);

		#define PARALLAX_HEIGHT_TEXTURE_ARRAY _HeightTextures
		#include "POM.cginc"

		float4 _MaterialColors[50];
		float4 _MaterialData[50];
		float4 _PartData[25];

		static const float4 METALLIC_COLOUR = float4(0.6, 0.6, 0.6, 1);

		struct Input
		{
			float2 texcoord;
			float4 ids;

			float3 posWorld;
			float3 tSpace0;
			float3 tSpace1;
			float3 tSpace2;
		};

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);

			o.texcoord = float2((v.texcoord.x * v.texcoord1.x) + frac(v.texcoord1.z), (v.texcoord.y * v.texcoord1.y) + frac(v.texcoord1.w));
			o.texcoord /= v.texcoord.z + 1.f;

			o.ids = float4(frac(v.texcoord.w) * 100, floor(v.texcoord1.z), floor(v.texcoord1.w), v.texcoord.w);

			o.posWorld = mul(unity_ObjectToWorld, v.vertex);

			fixed3 worldNormal = mul(v.normal.xyz, (float3x3)unity_WorldToObject);
			fixed3 worldTangent =  normalize(mul((float3x3)unity_ObjectToWorld, v.tangent.xyz));
			fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
			o.tSpace0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
			o.tSpace1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
			o.tSpace2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float4 colour = _MaterialColors[IN.ids.x];
			float4 data = _MaterialData[IN.ids.x];
			float4 partData = _PartData[IN.ids.w];
			float2 texcoord = IN.texcoord;

			float3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - IN.posWorld.xyz);
			float3 tangentViewDir = IN.tSpace0.xyz * worldViewDir.x + IN.tSpace1.xyz * worldViewDir.y  + IN.tSpace2.xyz * worldViewDir.z;

			ParallaxOcclusionMapping(
				IN.ids.y,
				PARALLAX_STRENGTH,
				MIN_SAMPLES, MAX_SAMPLES,
				tangentViewDir,
				texcoord
			);

			float2 texDetail = UNITY_SAMPLE_TEX2DARRAY(_DetailTextures, float3(texcoord, IN.ids.y)).rg;
			colour.rgb += (texDetail.r - 0.5019608) * data.z;
			colour.rgb = saturate(colour.rgb);

			float4 texNormal = UNITY_SAMPLE_TEX2DARRAY(_NormalMapTextures, float3(texcoord, IN.ids.z));
			fixed3 localNormal = UnpackNormal(texNormal);
			localNormal.xy *= data.z;
			localNormal.z += 0.0001;

			float4 metalnessRoughnessAOMask = UNITY_SAMPLE_TEX2DARRAY(_MRAOTextures, float3(texcoord, IN.ids.y));
			metalnessRoughnessAOMask = lerp(
				float4(data.x, 1.f - data.y, 1.f, 1.f),
				metalnessRoughnessAOMask,
				saturate(data.z)
			);

			o.Albedo = UNITY_SAMPLE_TEX2DARRAY(_HeightTextures, float3(texcoord, IN.ids.y)).r;
			//o.Albedo = lerp(METALLIC_COLOUR, colour, metalnessRoughnessAOMask.a).rgb;
			o.Normal = localNormal;
			o.Metallic = metalnessRoughnessAOMask.r;
			o.Smoothness = 1.f - metalnessRoughnessAOMask.g;
			o.Occlusion = metalnessRoughnessAOMask.b;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
