class_name GamendResult
extends RefCounted

signal finished(result: GamendResult)

var response: ApiApiResponseClient
var error: ApiApiErrorClient
