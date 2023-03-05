namespace Assets.Scripts
{
	using System;
	using System.Collections.Generic;
	using System.Linq;
	using System.Text;
	using System.Reflection;
	using ModApi;
	using ModApi.Common;
	using ModApi.Mods;
	using UnityEngine;
	using HarmonyLib;

	[HarmonyPatch(typeof(Craft.Theme), "LoadMaterial", MethodType.Normal)]
	class ThemeLoadMaterialPatch
	{
		public static void PatchMaterial(in Material material)
		{
			if (material.shader.name == "Jundroo/SR Standard/SrStandardPartShader")
			{
				Debug.Log("[PBnJ] Patching material...");

				material.shader = Assets.Scripts.Mod.Instance.partShader;
				material.SetTexture("_MRAOTextures", Assets.Scripts.Mod.Instance.mraoTextures);
				material.SetTexture("_HeightTextures", Assets.Scripts.Mod.Instance.heightTextures);
			}
		}

		[HarmonyPostfix]
		static void Postfix(ref Material __result)
		{
			PatchMaterial(__result);
		}
	}

	/// <summary>
	/// A singleton object representing this mod that is instantiated and initialize when the mod is loaded.
	/// </summary>
	public class Mod : ModApi.Mods.GameMod
	{
		public Shader partShader;
		public Texture2DArray mraoTextures;
		public Texture2DArray heightTextures;

		/// <summary>
		/// Prevents a default instance of the <see cref="Mod"/> class from being created.
		/// </summary>
		private Mod() : base()
		{
		}

		/// <summary>
		/// Gets the singleton instance of the mod object.
		/// </summary>
		/// <value>The singleton instance of the mod object.</value>
		public static Mod Instance { get; } = GetModInstance<Mod>();

		protected override void OnModInitialized()
		{
			base.OnModInitialized();

			//originalPartShader = Shader.Find("Jundroo/SR Standard/SrStandardPartShader");
			partShader = this.ResourceLoader.LoadAsset<Shader>("Assets/Shaders/PartShaderRedux.shader");
			BuildTextureArrays();

			Harmony harmony = new Harmony("PhysicallyBasedAndJuno");
			harmony.PatchAll(Assembly.GetExecutingAssembly());

			PatchCurrentMaterials();

			Debug.Log("PBnJ Loaded Successfully");
		}

		private void PatchCurrentMaterials()
		{
			foreach (Material material in Resources.FindObjectsOfTypeAll<Material>())
			{
				ThemeLoadMaterialPatch.PatchMaterial(material);
			}
		}

		private Texture2D GetTexture(string type, string name, Texture2D fallback)
		{
			var texture = this.ResourceLoader.LoadAsset<Texture2D>(String.Format("Assets/Textures/{0}/{1}.png", type, name));

			if (texture == null)
			{
				Debug.LogFormat("No {0} texture for {1}, falling back to default", type, name);
				return fallback;
			}

			if (texture.format != fallback.format)
			{
				Debug.LogWarningFormat("{0} texture {1} has invalid format {2}, expected {3}", type, name, texture.format, fallback.format);
				return fallback;
			}

			if (texture.dimension != fallback.dimension)
			{
				Debug.LogWarningFormat("{0} texture {1} has invalid resolution {2}x{3}, expected {4}x{5}", type, name, texture.width, texture.height, fallback.width, fallback.height);
				return fallback;
			}

			if (texture.mipmapCount != fallback.mipmapCount)
			{
				Debug.LogWarningFormat("{0} texture {1} has invalid mipmap count {2}, expected {3}", type, name, texture.mipmapCount, fallback.mipmapCount);
				return fallback;
			}

			return texture;
		}

		private Texture2D GetMRAOTexture(string name, Texture2D fallback)
		{
			return GetTexture("MRAO", name, fallback);
		}

		private Texture2D GetHeightTexture(string name, Texture2D fallback)
		{
			return GetTexture("Height", name, fallback);
		}

		private T GetPropertyValue<T>(object instance, string name, bool isPublic = true)
		{
			BindingFlags flags = isPublic ? BindingFlags.Public : BindingFlags.NonPublic;
			return (T)instance.GetType().GetProperty(name, flags | BindingFlags.Instance).GetValue(instance);
		}

		private void BuildTextureArrays()
		{
			var styleManager = Game.Instance.PartStyleManager;

			FieldInfo detailTexturesFieldInfo = typeof(Craft.Parts.Styles.PartStyleManagerScript).GetField("_detailTextures", BindingFlags.NonPublic | BindingFlags.Instance);
			var detailTextures = detailTexturesFieldInfo.GetValue(styleManager);
			int numTextures = GetPropertyValue<int>(detailTextures, "Count");

			var defaultMRAOTexture = this.ResourceLoader.LoadAsset<Texture2D>("Assets/Textures/MRAO/Fallback.png");
			var defaultHeightTexture = this.ResourceLoader.LoadAsset<Texture2D>("Assets/Textures/Height/Fallback.png");

			mraoTextures = TextureArrayFromTexture(defaultMRAOTexture, numTextures, true, true);
			mraoTextures.Apply(false, true);

			heightTextures = TextureArrayFromTexture(defaultHeightTexture, numTextures, false, true);
			heightTextures.Apply(false, true);

			foreach (object texInfo in GetPropertyValue<IEnumerable<object>>(detailTextures, "Values"))
			{
				int arrayIndex = GetPropertyValue<int>(texInfo, "Index");
				string textureName = GetPropertyValue<string>(texInfo, "Id");

				Texture2D mraoTexture = GetMRAOTexture(textureName, defaultMRAOTexture);
				Texture2D heightTexture = GetHeightTexture(textureName, defaultHeightTexture);

				for (int mip = 0; mip < mraoTexture.mipmapCount; mip++)
				{
					Graphics.CopyTexture(mraoTexture, 0, mip, mraoTextures, arrayIndex, mip);
				}
				Graphics.CopyTexture(heightTexture, 0, 0, heightTextures, arrayIndex, 0);

				if (mraoTexture != defaultMRAOTexture)
				{
					Resources.UnloadAsset(mraoTexture);
				}
				if (heightTexture != defaultHeightTexture)
				{
					Resources.UnloadAsset(heightTexture);
				}
			}

			Resources.UnloadAsset(defaultMRAOTexture);
			Resources.UnloadAsset(defaultHeightTexture);
		}

		private Texture2DArray TextureArrayFromTexture(in Texture2D tex, int count, bool useMips, bool linear)
		{
			return new Texture2DArray(tex.width, tex.height, count, tex.format, useMips, linear);
		}
	}
}
