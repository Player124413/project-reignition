using System.Collections.Generic;
using Godot;

namespace Project.Gameplay.Bosses;

/// <summary> Generates a sword trail for Erazor's sword. </summary>
public partial class ErazorSwordTrail : Node3D
{
	[Export] public bool IsEmitting { get; set; }
	private MeshInstance3D trailMeshInstance;
	private ImmediateMesh trailMesh;

	/// <summary> How many trails to render. </summary>
	[Export] private int iterationCount = 1;
	/// <summary> How far apart to draw each trail to render. </summary>
	[Export] private float iterationSpacing = 0.2f;
	/// <summary> How tall each trail should be. /// </summary>
	[Export] private float height = 5f;
	/// <summary> How long each point should live. </summary>
	[Export] private float lifetime = .5f;
	[Export(PropertyHint.Layers3DRender)]
	private uint layer;
	[Export] public Material material;
	[Export] private Curve transparencyCurve;
	private readonly List<Point> points = []; // Data of each point
	private readonly List<float> pointLifetimes = []; // Lifetime of each point

	public override void _Ready()
	{
		trailMesh = new();

		// Actual mesh instance is parented at the bottom of the tree so trails render AFTER everything else has moved.
		trailMeshInstance = new()
		{
			Layers = layer,
			MaterialOverride = material,
			Mesh = trailMesh,
			CastShadow = GeometryInstance3D.ShadowCastingSetting.Off
		};

		GetTree().CurrentScene.CallDeferred(MethodName.AddChild, trailMeshInstance);
		VisibilityChanged += UpdateVisibility;
	}

	public override void _PhysicsProcess(double delta) => CallDeferred(MethodName.UpdateTrail, delta);

	private void UpdateVisibility() => trailMeshInstance.Visible = IsVisibleInTree();

	private void UpdateTrail(double delta)
	{
		trailMeshInstance.GlobalTransform = GlobalTransform;

		if (IsEmitting)
			AddPoint();

		for (int i = points.Count - 1; i >= 0; i--) // Update each point in reverse order
		{
			pointLifetimes[i] += (float)delta;
			if (pointLifetimes[i] >= lifetime)
				RemovePoint(i);
		}

		RenderTrail();
	}

	private void RenderTrail()
	{
		trailMesh.ClearSurfaces();

		if (points.Count < 2) // No points to render
			return;


		for (int i = 0; i < iterationCount; i++)
		{
			float currentIterationHeight = i * iterationSpacing;
			trailMesh.SurfaceBegin(Mesh.PrimitiveType.TriangleStrip, material);

			for (int x = 0; x < points.Count; x++)
			{
				float transparency = Mathf.Clamp(transparencyCurve.Sample(pointLifetimes[x] / lifetime), 0f, 1f);

				Vector3 normal = points[x].normal;
				Vector3 tangent = points[x].tangent;
				trailMesh.SurfaceSetColor(new(Colors.White, transparency));
				trailMesh.SurfaceSetNormal(normal);
				trailMesh.SurfaceAddVertex(ToLocal(points[x].position + normal * currentIterationHeight));

				trailMesh.SurfaceSetColor(new(Colors.White, transparency));
				trailMesh.SurfaceSetNormal(normal);
				trailMesh.SurfaceAddVertex(ToLocal(points[x].position + normal * currentIterationHeight + (tangent * height)));
			}

			trailMesh.SurfaceEnd();
		}
	}

	private void AddPoint()
	{
		Vector3 previousPosition = trailMeshInstance.GlobalPosition + this.Back();
		Vector3 tangentDirection = (previousPosition - trailMeshInstance.GlobalPosition).Normalized();
		Vector3 normalDirection = tangentDirection.Rotated(this.Up(), Mathf.Pi * .5f);
		points.Add(new(GlobalPosition, normalDirection, tangentDirection));
		pointLifetimes.Add(0);
	}

	private void RemovePoint(int index)
	{
		points.RemoveAt(index);
		pointLifetimes.RemoveAt(index);
	}

	private class Point(Vector3 p, Vector3 n, Vector3 t)
	{
		public Vector3 position = p; // Origin of the point
		public Vector3 normal = n; // "Up" direction of the point
		public Vector3 tangent = t; // "Up" direction of the point
	}
}
