using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

/// <summary>
/// Plays an event (cutscene) with the correct audio depending on the localization settings
/// </summary>
[Tool]
public partial class EventPlayer : Node
{
	[ExportToolButton("Auto Setup")] public Callable AutoSetupCallable => new(this, MethodName.AutoSetup);

	[ExportGroup("Cutscene Settings")]
	/// <summary> Automatically load the given level when in Adventure Mode. Leave empty to return to the main menu. </summary>
	[Export(PropertyHint.File, "*.tres")] private LevelDataResource adventureLevelAutoload;
	/// <summary> Automatically load the given event when in Adventure Mode. Leave empty to return to the main menu. </summary>
	[Export(PropertyHint.File, "*.tscn")] private string adventureEventAutoload;
	[Export(PropertyHint.FilePath, "*.ogg")] private string englishAudioPath;
	[Export] private string localizationKeyPrefix;
	private Gameplay.Triggers.DialogTrigger subtitles;

	[ExportGroup("Components")]
	[Export] private AnimationPlayer animator;
	[Export] private AudioStreamPlayer audioPlayer;
	[Export] private VideoStreamFileLoadPlayer videoPlayer;

	[ExportGroup("Editor Only")]
	/// <summary> Subtitles used to preview cutscene in the editor. </summary>
	[Export] private Label editorSubtitleLabel;
	[Export] private Control editorSubtitleRoot;
	private int editorKeyIndex = 0;
	private int editorDialogIndex = 0;
	private double editorLastUpdateTime;
	private bool editorIsPlaybackInitialized;

	private bool IsSpecialBook => Menu.menuMemory[Menu.MemoryKeys.ActiveMenu] == (int)Menu.MemoryKeys.SpecialBook;

	private bool isCutsceneFinished;
	private float skipTimer;
	/// <summary> How long the pause button needs to be held to skip the cutscene. </summary>
	private readonly float SkipLength = 1f;

	public override void _Ready()
	{
		editorSubtitleRoot.Visible = false;

		if (Engine.IsEditorHint())
			return;

		LoadLocalization();
		CreateSubtitles();
		CallDeferred(MethodName.StartCutscene);

		if (IsSpecialBook)
			return;

		// Set up menu memory to match level data (Adventure Mode only)
		if (adventureLevelAutoload != null)
		{
			Menu.menuMemory[Menu.MemoryKeys.ActiveMenu] = (int)Menu.MemoryKeys.LevelSelect;
			Menu.menuMemory[Menu.MemoryKeys.WorldSelect] = (int)adventureLevelAutoload.AreaKey;
			Menu.menuMemory[Menu.MemoryKeys.LevelSelect] = adventureLevelAutoload.LevelIndex - 1;
		}
	}

	private void LoadLocalization()
	{
		if (animator == null)
			return;

		StringName targetLocale = SaveManager.VoiceLanguageToGodotLocale(SaveManager.Config.voiceLanguage);
		LoadAudioTrack(targetLocale);

		// Load timing animation
		if (!animator.HasAnimation(targetLocale))
			targetLocale = "en";

		animator.AssignedAnimation = targetLocale;
	}

	private void LoadAudioTrack(string targetLocale)
	{
		string targetAudio = englishAudioPath;
		if (targetAudio.Contains("/en/")) // localizable audio
		{
			targetAudio = targetAudio.Replace("/en/", $"/{targetLocale}/");

			if (!ResourceLoader.Exists(targetAudio)) // Revert to english
			{
				GD.PushError($"Couldn't find audio at {targetAudio}!");
				targetAudio = englishAudioPath;
			}
		}

		if (audioPlayer.Stream != null && audioPlayer.Stream.ResourcePath.Equals(targetAudio))
			return;

		// Load audio
		audioPlayer.Stream = ResourceLoader.Load<AudioStreamOggVorbis>(targetAudio);
	}

	private void AutoSetup()
	{
		string name = Name.ToString().ToCamelCase();

		// Get event number
		string eventNumber = string.Empty;
		for (int i = name.Length - 1; i >= 0; i--)
		{
			if (name[i] < '0' || name[i] > '9')
				break;

			eventNumber = $"{name[i]}{eventNumber}";
		}

		if (string.IsNullOrEmpty(eventNumber))
		{
			GD.PrintErr("Couldn't find an event number in the node's name! Cancelling auto-setup.");
			return;
		}

		while (eventNumber.Length < 2)
			eventNumber = $"0{eventNumber}";

		string targetAudioPath = $"res://video/event/en/{name}.ogg";
		if (ResourceLoader.Exists(targetAudioPath))
			englishAudioPath = targetAudioPath;

		localizationKeyPrefix = $"event{eventNumber}_";

		videoPlayer.SetVideoFilePath($"res://video/event/stream/E00{eventNumber}.mp4");

		animator = GetChildOrNull<AnimationPlayer>(-1);
		if (animator != null) // Animator is already set up.
			return;

		animator = new AnimationPlayer
		{
			Name = "AnimationPlayer"
		};
		AddChild(animator);
		animator.Owner = GetTree().EditedSceneRoot;

		// Create default anim
		Animation enAnim = new();
		enAnim.AddTrack(Animation.TrackType.Method);
		enAnim.TrackSetPath(0, ".");
		enAnim.Step = 0.1f;

		LoadAudioTrack("en");
		if (audioPlayer.Stream != null)
		{
			enAnim.Length = Mathf.CeilToInt(audioPlayer.Stream.GetLength());
			audioPlayer.Stream = null;
		}

		// Create animation library
		AnimationLibrary animLibrary = new();
		animLibrary.AddAnimation("en", enAnim);

		animator.AddAnimationLibrary(string.Empty, animLibrary);
	}

	private void StartCutscene()
	{
		videoPlayer.Play();
		audioPlayer.Play();

		if (animator != null)
		{
			animator.Seek(0.0);
			animator.Play();
		}

		subtitles?.Activate();
	}

	public override void _PhysicsProcess(double _)
	{
		if (Engine.IsEditorHint())
		{
			ResyncEditorIndex();
			return;
		}

		if (isCutsceneFinished)
		{
			SoundManager.FadeAudioPlayer(audioPlayer, 0.5f);
			return;
		}

		if (TransitionManager.IsTransitionActive)
			return;

		if (Menu.menuMemory[Menu.MemoryKeys.ActiveMenu] != (int)Menu.MemoryKeys.SpecialBook)
		{
			// Process skipping story cutscene
			if (Runtime.Instance.IsActionPressed("sys_pause", "ui_accept") && !Input.IsActionJustPressed("toggle_fullscreen"))
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
		if (animator == null) // No subtitles, apparently
			return;

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
		float accumulatedDelay = (float)currentAnimation.TrackGetKeyTime(0, 0);

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
		isCutsceneFinished = true;
		if (!IsSpecialBook && adventureLevelAutoload != null)
		{
			// Load to level
			TransitionManager.QueueSceneChange(adventureLevelAutoload.LevelPath);
			TransitionManager.StartTransition(new()
			{
				inSpeed = 1f,
				color = Colors.Black,
				loadAsynchronously = true,
				disableAutoTransition = true,
				showMissionDescription = true
			});
			TransitionManager.Instance.SetMissionDescriptionText(adventureLevelAutoload.MissionTypeKey, adventureLevelAutoload.MissionDescriptionKey);
			TransitionManager.Instance.UpdateLoadingText("load_level");
			return;
		}

		string targetScene = TransitionManager.MenuScenePath;
		if (IsSpecialBook)
			targetScene = TransitionManager.SpecialBookScenePath;
		else if (!string.IsNullOrEmpty(adventureEventAutoload))
			targetScene = adventureEventAutoload;

		if (targetScene.Equals(TransitionManager.MenuScenePath))
		{
			TransitionManager.Instance.QueuedScene = targetScene;
			NotificationManager.Instance.StartNotifications();
			return;
		}

		TransitionManager.QueueSceneChange(targetScene);
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
		editorSubtitleLabel.Text = Tr($"{localizationKeyPrefix}{editorDialogIndex}");
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
		LoadAudioTrack(animator.CurrentAnimation);

		audioPlayer.Play((float)animator.CurrentAnimationPosition);
		InitializeEditorIndex();
	}

	private void PauseFromEditor()
	{
		audioPlayer.Stop();
		audioPlayer.Stream = null;
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
		if (animator == null)
			return;

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

		if (editorKeyIndex >= currentAnimation.TrackGetKeyCount(0) ||
			currentAnimation.TrackGetKeyTime(0, editorKeyIndex) > animator.CurrentAnimationPosition)
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
