# GitHub Pages 部署说明

本项目是纯静态 H5，可以直接通过 GitHub Pages 发布。

## 首次启用

1. 打开 GitHub 仓库：`https://github.com/lijiewang/family-stars-h5`
2. 进入 `Settings` -> `Pages`
3. 在 `Build and deployment` 中，将 `Source` 选择为 `GitHub Actions`
4. 保存后，推送到 `main` 分支会自动发布

## 发布地址

发布成功后，默认访问地址通常是：

`https://lijiewang.github.io/family-stars-h5/`

## 后续更新

每次将代码推送到 `main` 分支，GitHub Actions 会自动执行 `.github/workflows/github-pages.yml`，并重新发布页面。

也可以在 GitHub 仓库的 `Actions` 页面中，手动运行 `Deploy to GitHub Pages`。
