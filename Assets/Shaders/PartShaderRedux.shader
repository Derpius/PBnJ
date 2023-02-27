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
		#pragma target 3.0

		UNITY_DECLARE_TEX2DARRAY(_DetailTextures);
		UNITY_DECLARE_TEX2DARRAY(_NormalMapTextures);

		fixed4 SampleTexArray(UNITY_ARGS_TEX2DARRAY(_TexArray), float2 uv, float index) {
			return UNITY_SAMPLE_TEX2DARRAY(_TexArray, float3(uv, index));
		}

		float4 _MaterialColors[50];
		float4 _MaterialData[50];
		float4 _PartData[25];

		struct Input
		{
			float2 texCoords;
			float4 ids;
		};

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);

			o.texCoords = float2((v.texcoord.x * v.texcoord1.x) + frac(v.texcoord1.z), (v.texcoord.y * v.texcoord1.y) + frac(v.texcoord1.w));
			o.texCoords /= v.texcoord.z + 1.f;

			o.ids = float4(frac(v.texcoord.w) * 100, floor(v.texcoord1.z), floor(v.texcoord1.w), v.texcoord.w);
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float4 colour = _MaterialColors[IN.ids.x];
			float4 data = _MaterialData[IN.ids.x];
			float4 partData = _PartData[IN.ids.w];

			float2 texDetail = UNITY_SAMPLE_TEX2DARRAY(_DetailTextures, float3(IN.texCoords, IN.ids.y)).rg;
			colour.rgb += (texDetail.r - 0.5019608) * data.z;
			colour.rgb = saturate(colour.rgb);

			float4 texNormal = UNITY_SAMPLE_TEX2DARRAY(_NormalMapTextures, float3(IN.texCoords, IN.ids.z));
			fixed3 localNormal = UnpackNormal(texNormal);
			localNormal.xy *= data.z;
			localNormal.z += 0.0001;

			o.Albedo = colour;
			o.Normal = localNormal;
			o.Metallic = data.x;
			o.Smoothness = data.y;
			o.Alpha = 1.f;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
