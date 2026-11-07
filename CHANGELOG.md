# Changelog

## [0.9.0](https://github.com/studiobimo/project-template/compare/v0.8.0...v0.9.0) (2026-11-07)


### Features

* **devtools:** deploy production only, without a development environment or a develop branch ([#61](https://github.com/studiobimo/project-template/issues/61)) ([889dcd6](https://github.com/studiobimo/project-template/commit/889dcd63f4917b733bb45799e52d8d6167be1e61))
* **devtools:** make every workspace package extend the full shared config ([#64](https://github.com/studiobimo/project-template/issues/64)) ([c74f561](https://github.com/studiobimo/project-template/commit/c74f561b3d48803db5f3e8d287faba4bcfc89879))

## [0.8.0](https://github.com/studiobimo/project-template/compare/v0.7.0...v0.8.0) (2026-11-07)


### ⚠ BREAKING CHANGES

* **devtools:** deploy to development and production, named after their branches ([#58](https://github.com/studiobimo/project-template/issues/58))

### Features

* **devtools:** build, budget and deploy more than one app in a workspace ([#56](https://github.com/studiobimo/project-template/issues/56)) ([0a4f911](https://github.com/studiobimo/project-template/commit/0a4f911cb6349736a256d53df33b2bd0b358c026))
* **devtools:** deploy to development and production, named after their branches ([#58](https://github.com/studiobimo/project-template/issues/58)) ([08449a2](https://github.com/studiobimo/project-template/commit/08449a200df3f7d9c0f0031f64b1a9b1ee15bce6))

## [0.7.0](https://github.com/studiobimo/project-template/compare/v0.6.0...v0.7.0) (2026-11-07)


### Features

* **ci:** report outdated mise tools weekly ([#50](https://github.com/studiobimo/project-template/issues/50)) ([13a19b9](https://github.com/studiobimo/project-template/commit/13a19b98f0b6659bd631809febfb1a08b6671881))


### Bug Fixes

* **ci:** let a project name its own dependabot target branch ([#46](https://github.com/studiobimo/project-template/issues/46)) ([7f40e9c](https://github.com/studiobimo/project-template/commit/7f40e9cea1302003834add53c1edab135cab9191))
* **devtools:** leave src/components/ui out of the eslint config ([#48](https://github.com/studiobimo/project-template/issues/48)) ([c4c3d46](https://github.com/studiobimo/project-template/commit/c4c3d4608824903494bf2d33b5351429631cf685))
* **devtools:** skip badges in the description and list tailwindcss in the app ([#47](https://github.com/studiobimo/project-template/issues/47)) ([946e309](https://github.com/studiobimo/project-template/commit/946e30917aeb5a41ef5f2d8380b39c6d375b2ed1))
* **docs:** say what a private repository gets and stop naming release-please ([#49](https://github.com/studiobimo/project-template/issues/49)) ([d46b2f5](https://github.com/studiobimo/project-template/commit/d46b2f52f7c21bd66ab9d3c22b3a23cbcec2586c))

## [0.6.0](https://github.com/studiobimo/project-template/compare/v0.5.0...v0.6.0) (2026-11-02)


### Features

* **devtools:** install the playwright browser from one shared target ([#44](https://github.com/studiobimo/project-template/issues/44)) ([aef96a7](https://github.com/studiobimo/project-template/commit/aef96a7409851e896c3545de4bd47c2fac8c49a1))

## [0.5.0](https://github.com/studiobimo/project-template/compare/v0.4.1...v0.5.0) (2026-11-01)


### Features

* **devtools:** add required manifest entries and review override files ([#29](https://github.com/studiobimo/project-template/issues/29)) ([3c0698b](https://github.com/studiobimo/project-template/commit/3c0698b3c7cc163106178472b947ef71a96a8d77))
* **devtools:** add the cloudflare hosting profile ([#23](https://github.com/studiobimo/project-template/issues/23)) ([2f7f161](https://github.com/studiobimo/project-template/commit/2f7f16193d007d210856c04d6de32a4a73423ed3))
* **devtools:** add the gcp hosting profile ([#25](https://github.com/studiobimo/project-template/issues/25)) ([4ec4b65](https://github.com/studiobimo/project-template/commit/4ec4b65cb8713b6378de125560774b3b78120395))
* **devtools:** add the vite-react-tanstack profile ([#22](https://github.com/studiobimo/project-template/issues/22)) ([f83b0e5](https://github.com/studiobimo/project-template/commit/f83b0e53340c42b910347e2ebfb7982d9fc9bffe))
* **devtools:** deploy the cloudflare profile from github actions ([#26](https://github.com/studiobimo/project-template/issues/26)) ([bb5498a](https://github.com/studiobimo/project-template/commit/bb5498a5c8e1e49be7eeefc5fe533cefcd9e531c))
* **devtools:** hold issue titles to conventional commits ([#32](https://github.com/studiobimo/project-template/issues/32)) ([b90ac34](https://github.com/studiobimo/project-template/commit/b90ac34df441aaee02558b0048a1e1aa34af4e8e))
* **devtools:** let the web profiles run from an app directory ([#36](https://github.com/studiobimo/project-template/issues/36)) ([f57c60c](https://github.com/studiobimo/project-template/commit/f57c60cbbc4271fee82315c8f879b90634d3e0d6))
* **devtools:** run the gcp profile from an app directory ([#38](https://github.com/studiobimo/project-template/issues/38)) ([cb55194](https://github.com/studiobimo/project-template/commit/cb55194029c27ed767c7548982b07d4a44363930))
* **devtools:** share the eslint and vitest configs with workspace packages ([#37](https://github.com/studiobimo/project-template/issues/37)) ([6be3f06](https://github.com/studiobimo/project-template/commit/6be3f06eef6fd48a4d74f227d2d32325fa294fbc))


### Bug Fixes

* **deps:** refresh the check-jsonschema lock for certifi 2026.10.19 ([#28](https://github.com/studiobimo/project-template/issues/28)) ([8c8447f](https://github.com/studiobimo/project-template/commit/8c8447f7a45b4d83efb14165796adea518e00852))
* **devtools:** centralize the profiles' strings and pin the shadcn cli ([#33](https://github.com/studiobimo/project-template/issues/33)) ([301fe04](https://github.com/studiobimo/project-template/commit/301fe04bfb9f0c12597012567b3b05913a7b8f5f))
* **devtools:** keep a project's lines when a managed block loses its end marker ([#31](https://github.com/studiobimo/project-template/issues/31)) ([d9fa068](https://github.com/studiobimo/project-template/commit/d9fa068c5dc63d5ffa0c2ee37f6f277c47a8dbe6))
* **devtools:** leave the generated changelog out of typos ([#30](https://github.com/studiobimo/project-template/issues/30)) ([7cea7ca](https://github.com/studiobimo/project-template/commit/7cea7ca5066302eceaaf66d869c4a1b482ea01a2))

## [0.4.1](https://github.com/studiobimo/project-template/compare/v0.4.0...v0.4.1) (2026-10-10)


### Bug Fixes

* **devtools:** pass Spotless a String for the external sources exclude ([#19](https://github.com/studiobimo/project-template/issues/19)) ([0e57686](https://github.com/studiobimo/project-template/commit/0e5768609d7a743a015656c1e963367205c0d39a))

## [0.4.0](https://github.com/studiobimo/project-template/compare/v0.3.2...v0.4.0) (2026-10-09)


### Features

* **devtools:** add the java-gradle profile ([#17](https://github.com/studiobimo/project-template/issues/17)) ([b5ae8cd](https://github.com/studiobimo/project-template/commit/b5ae8cd98efd1053c8d5946511a5778f4a41ffa8))

## [0.3.2](https://github.com/studiobimo/project-template/compare/v0.3.1...v0.3.2) (2026-10-09)


### Bug Fixes

* **docs:** say a change to a managed file must be a fix or feat to ship ([#15](https://github.com/studiobimo/project-template/issues/15)) ([f8f3840](https://github.com/studiobimo/project-template/commit/f8f3840b12695d03884bf5ff03d0c4c3c7c0f758))

## [0.3.1](https://github.com/studiobimo/project-template/compare/v0.3.0...v0.3.1) (2026-10-09)


### Bug Fixes

* **devtools:** follow v1 for the hook rules and make the mise block stand alone ([#11](https://github.com/studiobimo/project-template/issues/11)) ([cd1b01a](https://github.com/studiobimo/project-template/commit/cd1b01a3189bfe315313d538e86016c3d406c9c9))

## [0.3.0](https://github.com/studiobimo/project-template/compare/v0.2.0...v0.3.0) (2026-10-09)


### Features

* **devtools:** pin the tools with mise ([#7](https://github.com/studiobimo/project-template/issues/7)) ([4dbd1df](https://github.com/studiobimo/project-template/commit/4dbd1df47318b5c75fa9a692dfcb9f05dfd8d52e))
* **devtools:** run the hooks with lefthook and commitlint ([#8](https://github.com/studiobimo/project-template/issues/8)) ([0918ebf](https://github.com/studiobimo/project-template/commit/0918ebf2d0b2308f0b2e922ef26ff62e357c3a1e))

## [0.2.0](https://github.com/studiobimo/project-template/compare/v0.1.0...v0.2.0) (2026-10-09)


### Features

* **devtools:** set up the repository on GitHub from init ([#4](https://github.com/studiobimo/project-template/issues/4)) ([9c46c68](https://github.com/studiobimo/project-template/commit/9c46c68f8379acbef8f0e934323d6cc381106eca))


### Documentation

* **readme:** add workflow status badges ([#5](https://github.com/studiobimo/project-template/issues/5)) ([47e9677](https://github.com/studiobimo/project-template/commit/47e9677517be4b413d888e4eca8fc84c580bca30))

## 0.1.0 (2026-10-09)


### Features

* add the project template ([fbb5de0](https://github.com/studiobimo/project-template/commit/fbb5de0d2234d98fc78f07d14eb7101eb43d16a9))
