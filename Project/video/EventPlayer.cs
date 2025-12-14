using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;

/// <summary>
/// Plays an event (cutscene) with the correct audio depending on the localization settings
/// </summary>
[Tool]
public partial class EventPlayer : Node
{
	[ExportToolButton("Play")] private Callable Play => new(this, MethodName.PlayFromEditor);
	[ExportToolButton("Pause")] private Callable Pause => new(this, MethodName.PauseFromEditor);

	[ExportGroup("Cutscene Settings")]
	[Export] private string englishAudioPath;
	[Export] private string localizationKeyPrefix;
	/// <summary> Optional key for unlocking a world ring. Use Lost Prologue for no world ring. </summary>
	[Export] private SaveManager.WorldEnum worldRing = SaveManager.WorldEnum.LostPrologue;
	private Gameplay.Triggers.DialogTrigger subtitles;

	[ExportGroup("Components")]
	[Export] private AnimationPlayer animator;
	[Export] private AudioStreamPlayer audioPlayer;
	[Export] private VideoStreamPlayer videoPlayer;

	[ExportGroup("Editor Only")]
	/// <summary> Subtitles used to preview cutscene in the editor. </summary>
	[Export] private Label editorSubtitleLabel;
	[Export] private Control editorSubtitleRoot;
	[Export] private int editorEventNumber = 1;
	private int editorKeyIndex = 0;
	private int editorDialogIndex = 0;
	private double editorLastUpdateTime;
	private bool editorIsPlaybackInitialized;

	private bool IsSpecialBook => Menu.menuMemory[Menu.MemoryKeys.ActiveMenu] == (int)Menu.MemoryKeys.SpecialBook;

	private float skipTimer;
	/// <summary> How long the pause button needs to be held to skip the cutscene. </summary>
	private readonly float SkipLength = 1f;
	/// <summary> Dialog keys are offset by this much so the fade-in lines up with the editor preview. </summary>
	private readonly float InitialSubtitleOffset = 0.2f;

	public override void _Ready()
	{
		editorSubtitleRoot.Visible = false;

		if (Engine.IsEditorHint())
			return;

		LoadLocalization();
		CreateSubtitles();
		CallDeferred(MethodName.StartCutscene);

		if (worldRing != SaveManager.WorldEnum.LostPrologue && !SaveManager.ActiveGameData.IsWorldRingObtained(worldRing))
		{
			SaveManager.ActiveGameData.UnlockWorldRing(worldRing);
			NotificationManager.Instance.AddNotification(NotificationManager.NotificationType.WorldRing, $"unlock_ring_{worldRing.ToString().ToSnakeCase()}");
		}
	}

	private void LoadLocalization()
	{
		StringName targetLocale;
		targetLocale = SaveManager.Config.voiceLanguage switch
		{
			SaveManager.VoiceLanguage.Japanese => (StringName)"ja",
			SaveManager.VoiceLanguage.Spanish => (StringName)"es",
			_ => (StringName)"en",
		};

		// Load audio
		string targetAudio = englishAudioPath.Replace("/en/", $"/{targetLocale}/");
		if (!ResourceLoader.Exists(targetAudio))
		{
			GD.PushError($"Couldn't find audio at {targetAudio}!");
			targetAudio = englishAudioPath;
		}

		audioPlayer.Stream = ResourceLoader.Load<AudioStreamOggVorbis>(targetAudio);

		// Load timing animation
		if (!animator.HasAnimation(targetLocale))
			targetLocale = "en";

		animator.AssignedAnimation = targetLocale;
	}

	private void StartCutscene()
	{
		videoPlayer.Play();
		audioPlayer.Play();
		animator.Seek(0.0);
		animator.Play();

		subtitles?.Activate();
	}

	public override void _PhysicsProcess(double _)
	{
		if (Engine.IsEditorHint())
		{
			ResyncEditorIndex();
			return;
		}

		if (TransitionManager.IsTransitionActive)
			return;

		if (Menu.menuMemory[Menu.MemoryKeys.ActiveMenu] != (int)Menu.MemoryKeys.SpecialBook)
		{
			// Process skipping story cutscene
			if (Runtime.Instance.IsActionJustPressed("sys_pause", "ui_accept") && !Input.IsActionJustPressed("toggle_fullscreen"))
			{
				skipTimer = Mathf.MoveToward(skipTimer, SkipLength, PhysicsManager.physicsDelta);
				if (Mathf.IsEqualApprox(skipTimer, SkipLength))
					OnEventFinished();

				return;
			}

			skipTimer = Mathf.MoveToward(skipTimer, 0, PhysicsManager.physicsDelta);
			return;
		}

		// Allow players to exit immediately when viewing from the special book
		if (Runtime.Instance.IsActionJustPressed("sys_cancel", "ui_cancel", "escape"))
			OnEventFinished();
	}

	/// <summary> Creates a dialog trigger based on the keyframes in an animation. </summary>
	private void CreateSubtitles()
	{
		subtitles = new Gameplay.Triggers.DialogTrigger()
		{
			IsCutscene = true,
			delays = [],
			displayLength = [],
			textKeys = [],
		};
		AddChild(subtitles);

		Animation currentAnimation = animator.GetAnimation(animator.AssignedAnimation);
		int currentDialogIndex = 0;
		float accumulatedDelay = (float)currentAnimation.TrackGetKeyTime(0, 0) - InitialSubtitleOffset;
		for (int i = 0; i < currentAnimation.TrackGetKeyCount(0); i++)
		{
			Dictionary currentKeyData = currentAnimation.TrackGetKeyValue(0, i).As<Dictionary>();

			// Calculate key length
			double currentKeyTime = currentAnimation.TrackGetKeyTime(0, i);
			float keyLength;
			if (i == currentAnimation.TrackGetKeyCount(0) - 1) // Final key; hide at the end of the cutscene
				keyLength = currentAnimation.Length - (float)currentKeyTime;
			else // Change text at next key
				keyLength = (float)(currentAnimation.TrackGetKeyTime(0, i + 1) - currentKeyTime);

			StringName method = currentKeyData["method"].As<StringName>();

			if (method.Equals(MethodName.ShowSubtitles)) // Add a new key
			{
				currentDialogIndex++;
				subtitles.textKeys.Add($"{localizationKeyPrefix}{currentDialogIndex}");
				subtitles.delays.Add(accumulatedDelay);
				subtitles.displayLength.Add(keyLength);

				accumulatedDelay = 0f;
				continue;
			}

			// Delay the next key
			accumulatedDelay += keyLength;
		}
	}

	/// <summary> Called after the cutscene has finished playing. </summary>
	public void OnEventFinished()
	{
		TransitionManager.QueueSceneChange(IsSpecialBook ? TransitionManager.SpecialBookScenePath : TransitionManager.MenuScenePath);
		TransitionManager.StartTransition(new TransitionData()
		{
			color = Colors.Black,
			inSpeed = .5f,
		});
	}

	private void ShowSubtitles()
	{
		if (!Engine.IsEditorHint())
			return;

		editorSubtitleRoot.Visible = true;
		editorSubtitleLabel.Text = Tr($"event{editorEventNumber}_{editorDialogIndex}");
	}

	private void HideSubtitles()
	{
		if (!Engine.IsEditorHint())
			return;

		editorSubtitleRoot.Visible = false;
	}

	private void PlayFromEditor()
	{
		animator.Play();
		audioPlayer.Play((float)animator.CurrentAnimationPosition);
		InitializeEditorIndex();
	}

	private void PauseFromEditor()
	{
		audioPlayer.Stop();
		animator.Pause();
		editorIsPlaybackInitialized = false;
	}

	private void InitializeEditorIndex()
	{
		if (string.IsNullOrEmpty(animator.CurrentAnimation))
			return;

		editorKeyIndex = 0;
		editorDialogIndex = 0;
		editorLastUpdateTime = animator.CurrentAnimationPosition;
		HideSubtitles();

		Animation currentAnimation = animator.GetAnimation(animator.CurrentAnimation);
		for (int i = 0; i < currentAnimation.TrackGetKeyCount(0); i++)
		{
			if (currentAnimation.TrackGetKeyTime(0, i) > editorLastUpdateTime)
				break;

			ProcessEditorKeyframe(currentAnimation.TrackGetKeyValue(0, i).As<Dictionary>());
		}

		editorIsPlaybackInitialized = true;
	}

	private void ResyncEditorIndex()
	{
		if (string.IsNullOrEmpty(animator.CurrentAnimation))
		{
			if (editorIsPlaybackInitialized)
				PauseFromEditor();

			return;
		}

		if (!editorIsPlaybackInitialized)
		{
			PlayFromEditor();
			return;
		}

		Animation currentAnimation = animator.GetAnimation(animator.CurrentAnimation);

		GD.PrintT(editorKeyIndex, currentAnimation.TrackGetKeyTime(0, editorKeyIndex), animator.CurrentAnimationPosition);
		if (currentAnimation.TrackGetKeyTime(0, editorKeyIndex) > animator.CurrentAnimationPosition ||
			editorKeyIndex >= currentAnimation.TrackGetKeyCount(0))
		{
			return;
		}

		ProcessEditorKeyframe(currentAnimation.TrackGetKeyValue(0, editorKeyIndex).As<Dictionary>());
		editorLastUpdateTime = animator.CurrentAnimationPosition;
	}

	private void ProcessEditorKeyframe(Dictionary key)
	{
		editorKeyIndex++;

		StringName method = key["method"].As<StringName>();

		if (method.Equals(MethodName.ShowSubtitles))
		{
			editorDialogIndex++;
			ShowSubtitles();
			return;
		}

		if (method.Equals(MethodName.HideSubtitles))
			HideSubtitles();
	}
}
