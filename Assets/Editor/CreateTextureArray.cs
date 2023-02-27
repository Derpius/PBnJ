using System;
using UnityEngine;
using UnityEditor;

public class CreateTextureArray
{
	[MenuItem("Assets/Create Texture Array")]
	private static void MenuOption()
	{
		Texture2D[] textures = Array.ConvertAll(Selection.objects, (obj) => (Texture2D)obj);
		Texture2DArray textureArray = new Texture2DArray(textures[0].width, textures[0].height, textures.Length, textures[0].format, false);

		for (int i = 0; i < textures.Length; i++)
		{
			textureArray.SetPixels(textures[i].GetPixels(), i);
		}

		textureArray.Apply();
		ProjectWindowUtil.CreateAsset(textureArray, "TextureArray.asset");
	}

	[MenuItem("Assets/Create Texture Array", true)]
	private static bool ValidateMenuOption()
	{
		UnityEngine.Object[] selection = Selection.objects;
		if (selection.Length < 1)
		{
			return false;
		}

		for (int i = 0; i < selection.Length; i++)
		{
			if (selection[i].GetType() != typeof(Texture2D))
			{
				return false;
			}
		}

		for (int i = 1; i < selection.Length; i++)
		{
			if (!TexturesAreCompatible((Texture2D)selection[0], (Texture2D)selection[i]))
			{
				return false;
			}
		}

		return true;
	}

	private static bool TexturesAreCompatible(Texture2D a, Texture2D b)
	{
		return a.dimension == b.dimension && a.format == b.format;
	}
}
