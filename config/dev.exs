import Config

config :git_ops,
  changelog_file: "CHANGELOG.md",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  mix_project: SpandexPhoenix.MixProject,
  repository_url: "https://github.com/spandex-project/spandex_phoenix",
  version_tag_prefix: "v"
