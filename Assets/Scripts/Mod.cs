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
			mraoTextures = BuildMRAOTextureArray();

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

		private Texture2D GetMRAOTexture(string name, Texture2D fallback)
		{
			var texture = this.ResourceLoader.LoadAsset<Texture2D>("Assets/Textures/MRAO/" + name + ".png");

			if (texture == null)
			{
				Debug.LogFormat("No MRAO texture for {0}, falling back to default", name);
				return fallback;
			}

			if (texture.format != fallback.format)
			{
				Debug.LogWarningFormat("MRAO texture {0} has invalid format {1}, expected {2}", name, texture.format, fallback.format);
				return fallback;
			}

			if (texture.dimension != fallback.dimension)
			{
				Debug.LogWarningFormat("MRAO texture {0} has invalid resolution {1}x{2}, expected {3}x{4}", name, texture.width, texture.height, fallback.width, fallback.height);
				return fallback;
			}

			if (texture.mipmapCount != fallback.mipmapCount)
			{
				Debug.LogWarningFormat("MRAO texture {0} has invalid mipmap count {1}, expected {2}", name, texture.mipmapCount, fallback.mipmapCount);
				return fallback;
			}

			return texture;
		}

		private T GetPropertyValue<T>(object instance, string name, bool isPublic = true)
		{
			BindingFlags flags = isPublic ? BindingFlags.Public : BindingFlags.NonPublic;
			return (T)instance.GetType().GetProperty(name, flags | BindingFlags.Instance).GetValue(instance);
		}

		private Texture2DArray BuildMRAOTextureArray()
		{
			var styleManager = Game.Instance.PartStyleManager;

			FieldInfo detailTexturesFieldInfo = typeof(Craft.Parts.Styles.PartStyleManagerScript).GetField("_detailTextures", BindingFlags.NonPublic | BindingFlags.Instance);
			var detailTextures = detailTexturesFieldInfo.GetValue(styleManager);

			var defaultMRAOTexture = this.ResourceLoader.LoadAsset<Texture2D>("Assets/Textures/MRAO/Fallback.png");

			var texture2DArray = new Texture2DArray(defaultMRAOTexture.width, defaultMRAOTexture.height, GetPropertyValue<int>(detailTextures, "Count"), defaultMRAOTexture.format, true, true);
			texture2DArray.Apply(false, true);

			foreach (object texInfo in GetPropertyValue<IEnumerable<object>>(detailTextures, "Values"))
			{
				int arrayIndex = GetPropertyValue<int>(texInfo, "Index");
				string textureName = GetPropertyValue<string>(texInfo, "Id");

				Texture2D mraoTexture = GetMRAOTexture(textureName, defaultMRAOTexture);

				for (int mip = 0; mip < mraoTexture.mipmapCount; mip++)
				{
					Graphics.CopyTexture(mraoTexture, 0, mip, texture2DArray, arrayIndex, mip);
				}

				if (mraoTexture != defaultMRAOTexture)
				{
					Resources.UnloadAsset(mraoTexture);
				}
			}

			Resources.UnloadAsset(defaultMRAOTexture);

			return texture2DArray;
		}
	}
}
