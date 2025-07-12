# F-Droid Submission Guide for Block Drop

## What has been completed:

### 1. ✅ Upstream Metadata (in your project)

- `metadata/en-US/short_description.txt` - Short app description (30-50 chars)
- `metadata/en-US/full_description.txt` - Detailed app description
- `metadata/en-US/images/icon.png` - App icon for F-Droid
- `metadata/en-US/changelogs/1.txt` - Changelog for version 1
- `LICENSE` - MIT License file

### 2. ✅ Version Tags

- Your project already has the required `v1.0.0` git tag

### 3. ✅ F-Droid Metadata File

- Created `../fdroiddata/metadata/com.blockdrop.game.yml` with proper configuration
- Configured for Flutter/Gradle build system with complete Flutter installation
- Set up auto-update mode with version tags
- **APK Splitting**: Configured to build separate APKs for arm64-v8a, armeabi-v7a, and x86_64
- **Reproducible Builds**: Added configurations to ensure consistent builds

### 4. ✅ Android Build Configuration

- Updated `android/app/build.gradle.kts` with reproducible build settings:
  - Disabled VCS info inclusion (`vcsInfo.include false`)
  - Disabled PNG crunching (`cruncherEnabled = false`)
  - Disabled vector drawable generation (`vectorDrawables.generatedDensities = []`)
  - Configured APK splitting for multiple architectures
  - Added packaging options for deterministic builds

### 5. ✅ APK Splitting Setup

- Configured to build 3 separate APKs for different architectures:
  - arm64-v8a (version code 100)
  - armeabi-v7a (version code 101)
  - x86_64 (version code 102)
- Uses `VercodeOperation` to automatically generate version codes for each architecture

## Next Steps:

### 1. Fork and Submit to F-Droid

You need to:

1. Fork the fdroiddata repository on GitLab: https://gitlab.com/fdroid/fdroiddata
2. Push your branch `com.blockdrop.game` to your fork
3. Create a merge request from your fork to the main fdroiddata repository

### 2. Commands to push to your fork:

```bash
cd ../fdroiddata
git remote add origin https://gitlab.com/YOUR_GITLAB_USERNAME/fdroiddata.git
git push origin com.blockdrop.game
```

### 3. Create Merge Request

- Go to https://gitlab.com/fdroid/fdroiddata/-/merge_requests
- Create a new merge request
- Select your `com.blockdrop.game` branch as source
- Title: "New App: Block Drop (com.blockdrop.game)"

### 4. Testing (Optional but Recommended)

To test the build locally, you can use the F-Droid build tools:

```bash
cd ../fdroiddata
# Install Docker if not already installed
# Download and run the F-Droid build container
sudo docker run --rm -itu vagrant --entrypoint /bin/bash \
  -v ~/fdroiddata:/build:z \
  -v ~/fdroidserver:/home/vagrant/fdroidserver:Z \
  registry.gitlab.com/fdroid/fdroidserver:buildserver

# Inside the container:
. /etc/profile
export PATH="$fdroidserver:$PATH" PYTHONPATH="$fdroidserver"
cd /build
fdroid readmeta
fdroid rewritemeta com.blockdrop.game
fdroid lint com.blockdrop.game
fdroid build com.blockdrop.game
```

## Important Notes:

1. **Repository Access**: Make sure your GitHub repository is public and accessible
2. **Build Requirements**: The metadata is configured to use OpenJDK 17 for building
3. **Auto-Updates**: Once accepted, F-Droid will automatically detect new versions when you create new git tags
4. **Response Time**: F-Droid maintainers typically respond within a few days to weeks
5. **Follow Up**: Monitor your merge request for any feedback or requested changes

## File Structure Created:

```
block_drop/
├── LICENSE                                    # MIT License
├── metadata/
│   └── en-US/
│       ├── short_description.txt             # App short description
│       ├── full_description.txt              # App full description
│       ├── changelogs/
│       │   └── 1.txt                         # Version 1 changelog
│       └── images/
│           └── icon.png                      # App icon
└── F-DROID_SUBMISSION_GUIDE.md              # This guide

../fdroiddata/
└── metadata/
    └── com.blockdrop.game.yml                # F-Droid build metadata
```

Your project is now ready for F-Droid submission! 🎉
