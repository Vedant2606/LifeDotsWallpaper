# Life Dots Wallpaper — Native macOS project

This project is a standard macOS application target. It contains a real **Products** group and builds `LifeDotsWallpaper.app`.

## Build and install

1. Open `LifeDotsWallpaper.xcodeproj` in Xcode.
2. At the top, select **LifeDotsWallpaper → My Mac**.
3. Press **Shift + Command + K** to clean the build folder.
4. Press **Command + B** and wait for **Build Succeeded**.
5. In Xcode's Project Navigator, expand **Products**.
6. Right-click `LifeDotsWallpaper.app` and choose **Show in Finder**.
7. Drag the app into the main **Applications** folder.
8. Open the copy from Applications. If macOS asks, right-click it and choose **Open** once.
9. Set your DOB and preferences, then click **Generate & Set Wallpaper**.
10. Click **Install 6 AM Automation** from the installed copy.

There are no `.command` installer scripts in this build.

## Important

The automation deliberately refuses to install while the app is running from Xcode's DerivedData folder. This prevents broken or temporary app paths. Move the built `.app` into Applications first.
