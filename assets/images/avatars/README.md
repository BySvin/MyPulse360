# Avatar images

Drop profile picture files here, then set the matching user's `avatarUrl` to
`assets/images/avatars/<filename>` in `lib/shared/mock/fixtures/seed_users.dart`
(or wire it to a real upload later). `AvatarWidget` already renders any user
with a non-null `avatarUrl` as an image, falling back to initials otherwise.
