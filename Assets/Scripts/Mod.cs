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
	}
}
