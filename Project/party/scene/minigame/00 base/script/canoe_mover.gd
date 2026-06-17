### Base implemention for character controllers that are based on canoeing.
class_name PartyGameCanoeMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer : RollbackTimer
@export var character_body : CharacterBody3D
@export var oar_attachment : BoneAttachment3D

## Should turning be disabled? If so, the canoe will simply strafe side-to-side.
@export var disable_turning : bool
