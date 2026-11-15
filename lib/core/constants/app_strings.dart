/// AppStrings
/// 
/// This file defines all static user-facing text strings, labels,
/// notification titles, messages, units, and descriptions across the LifeMint application.
/// Strictly avoids hardcoded strings in presentation or business logic layers.
abstract class AppStrings {
  // App General & Branding
  static const String appName = 'LifeMint';
  static const String appTitle = 'LifeMint';
  static const String appTagline = 'Small steps\nA healthier you.';
  static const String splashSubtext = 'A better day starts with you.';
  static const String backgroundTrackerTitle = 'Background Wellness Service';
  static const String serviceRunning = 'Running';
  static const String serviceStopped = 'Stopped';
  static const String startService = 'Start Background Monitoring';
  static const String stopService = 'Stop Background Monitoring';
  static const String inCallMuted = 'In-Call / Ear (Alerts Muted)';
  static const String deviceRestingOnTable = 'Resting on Table (Tracking Paused)';
  static const String deviceAtEar = 'Phone at Ear (Alerts Muted)';
  static const String scrollingActive = 'Active Touch / Scrolling';
  static const String normalMode = 'Active Tracking';

  // Onboarding 1: Welcome
  static const String welcomeTitle = 'Build a healthier\ntomorrow';
  static const String welcomeSubtitle = "We'll help you remember the\nsmall things that matter.";
  static const String stayHydrated = 'Stay hydrated';
  static const String getNaturalSunlight = 'Get natural sunlight';
  static const String takeEyeBreaks = 'Take eye breaks';
  static const String trackYourMovement = 'Track your movement';
  static const String getStarted = 'Get Started';
  static const String skipForNow = 'Skip for now';

  // Onboarding 2: Select Habits
  static const String chooseWhatToTrack = 'Choose what to track';
  static const String chooseSubtitle = 'You can always change this later.';
  static const String habitWaterDesc = 'Drink water regularly';
  static const String habitSunlightDesc = 'Get natural sunlight';
  static const String habitEyeRestDesc = 'Take breaks from screens';
  static const String habitStepsDesc = 'Track your movement';
  static const String continueBtn = 'Continue';
  static const String illDoThisLater = "I'll do this later";

  // Onboarding 3: Connect Health Connect
  static const String connectHealthConnectTitle = 'Connect Health Connect';
  static const String connectHealthConnectSubtitle = 'We use Health Connect to read\nyour steps from Google Fit.';
  static const String secureAndPrivate = 'Secure and private';
  static const String standardAndroidFeature = 'Standard Android feature';
  static const String worksWithGoogleFit = 'Works with Google Fit';
  static const String connectHealthConnect = 'Connect Health Connect';
  static const String learnMore = 'Learn more';
  static const String learnHow = 'Learn how';

  // Onboarding 4: Permissions
  static const String allowPermissionsTitle = 'Allow permissions';
  static const String allowPermissionsSubtitle = 'These help us give you timely\nreminders and track your progress.';
  static const String permNotifications = 'Notifications';
  static const String permNotificationsDesc = 'For reminders';
  static const String permUsage = 'Usage access';
  static const String permUsageDesc = 'To detect screen usage\n(for eye rest)';
  static const String permHealthConnect = 'Health Connect';
  static const String permHealthConnectDesc = 'To read your steps';
  static const String permLocation = 'Location (Optional)';
  static const String permLocationDesc = 'For better sunlight reminders';
  static const String allow = 'Allow';
  static const String allowed = 'Allowed';

  // Navigation Tabs
  static const String tabHome = 'Today';
  static const String tabToday = 'Today';
  static const String tabProgress = 'Progress';
  static const String tabSettings = 'Settings';

  // Main Dashboard / Home
  static const String today = 'Today';
  static const String ofGoal = 'of';
  static const String breaks = 'breaks';
  static const String breaksUnit = 'breaks';
  static const String steps = 'Steps';

  // Progress Screen
  static const String progressTitle = 'Progress';
  static const String day = 'Day';
  static const String week = 'Week';
  static const String month = 'Month';
  static const String overallConsistency = 'Overall consistency';
  static const String vsLastWeek = 'vs last week';
  static const String bestStreak = 'Best streak';
  static const String daysStreak = '6 days';
  static const String habitBreakdown = 'Habit Breakdown';

  // Feature 1: Water Intake
  static const String waterTitle = 'Water';
  static const String waterSubtitle = 'Daily Water Goal & Reminders';
  static const String waterDesc = 'Personalized water target based on your body weight and daily activity.';
  static const String dailyIntake = 'Daily Intake';
  static const String targetGoal = 'Target Goal';
  static const String calculateGoal = 'Calculate by Weight';
  static const String enterWeightKg = 'Weight (kg)';
  static const String weightHelper = 'Recommended: 35 mL per kg body weight';
  static const String add100ml = '+100 ml';
  static const String add150ml = '+150 ml';
  static const String add250ml = '+250 ml';
  static const String add500ml = '+500 ml';
  static const String resetDailyWater = 'Reset Today';
  static const String lastDrink = 'Last drink';
  static const String waterNotificationTitle = 'Hydration Reminder';
  static const String waterNotificationBody = 'Time to drink a glass of water to keep your body hydrated!';
  static const String setWaterGoal = 'Set water goal';

  // Feature 2: Sunlight & Daylight
  static const String sunlightTitle = 'Sunlight';
  static const String sunlightSubtitle = 'Circadian Rhythm & Vitamin D';
  static const String sunlightDesc = 'Step outside into natural daylight to optimize sleep, mood, and eye health.';
  static const String dailySunlightGoal = 'Daily Outdoor Goal';
  static const String sunlightLoggedToday = 'Logged Today';
  static const String logSunlight = 'Log Sunlight';
  static const String startSunlightSession = 'Start Sunlight Session';
  static const String stopSunlightSession = 'Stop Session';
  static const String sunlightActive = 'Session in progress...';
  static const String sunlightTip = 'Try to get morning sunlight for better mood and sleep.';
  static const String sunlightNotificationTitle = 'Step into the Sunlight!';
  static const String sunlightNotificationBody = 'Get 15 minutes of natural daylight for healthy circadian rhythm and vitamin D.';

  // Feature 3: Eye Rest & Screen Breaks (20-20-20 Rule)
  static const String eyeRestTitle = 'Eye Rest';
  static const String eyeStrainSubtitle = '20-20-20 Screen Rest Rule';
  static const String eyeStrainDesc = 'Look at an object 20 feet away for 20 seconds to prevent digital eye strain.';
  static const String takeABreakNow = 'Take a Break Now';
  static const String eyeRestCompleted = 'Eyes Rested! Session Reset';
  static const String eyeRestTip = 'Look away for 20 seconds at something far away.';
  static const String eyeBreakNotificationTitle = 'Take an eye break';
  static const String eyeBreakNotificationBody = "You've been using your screen for a while. Look away for a moment.";
  static const String doneAction = 'Done';
  static const String remindMeIn5 = 'Remind me in 5 min';

  // Feature 4: Movement & Steps (Health Connect)
  static const String movementTitle = 'Steps';
  static const String movementSubtitle = 'Stretch & Anti-Sedentary Breaks';
  static const String stepsToday = 'steps today';
  static const String goalSteps = 'Goal: 8,000 steps';
  static const String distance = 'Distance';
  static const String calories = 'Calories';
  static const String caloriesUnit = 'kcal';
  static const String healthConnectTitle = 'Google Health Connect';
  static const String healthConnectConnected = 'Connected';
  static const String healthConnectGuideDesc = 'Steps and walking distance sync directly from Google Health Connect & Google Fit with zero manual entry.';
  static const String healthConnectPermissionNote = '1. On Android 14+, Health Connect is built-in under Settings > Security & Privacy.\n2. On Android 9–13, you can install Health Connect from Google Play.\n3. Grant "Steps" and "Distance" read permissions.';
  static const String healthConnectNotInstalledTitle = 'Health Connect Not Installed';
  static const String healthConnectNotInstalledDesc = 'Health Connect is required to sync your real walking steps from Google Fit or your smartwatch.';
  static const String healthConnectInstalledTitle = 'Health Connect Ready';
  static const String healthConnectInstalledDesc = 'Health Connect is available on your device. Connect now to sync your activity data.';
  static const String allowWriteAccessTitle = 'Allow read access\nfor Health Connect';
  static const String allowWriteAccessDesc = 'Please enable Read access for Steps and Distance in Health Connect to sync your daily activity.';
  static const String openSettings = 'Open Settings';
  static const String zeroStepsHelpTitle = 'Seeing 0 Steps?';
  static const String zeroStepsHelpDesc = 'Health Connect requires Read permission for Steps & Distance.\n\n1. Open Health Connect.\n2. Tap "App permissions" > LifeMint.\n3. Turn ON Read access for Steps & Distance.';
  static const String openHealthConnect = 'Open / Install Health Connect';
  static const String openGoogleFit = 'Open Google Fit';
  static const String installHealthConnectBtn = 'Install Health Connect';
  static const String syncHealthConnectBtn = 'Connect & Sync';
  static const String syncNow = 'Sync Now';

  // Settings Screen
  static const String settingsTitle = 'Settings';
  static const String dailyGoals = 'Daily goals';
  static const String reminders = 'Reminders';
  static const String permissions = 'Permissions';
  static const String appearance = 'Appearance';
  static const String about = 'About';
  static const String sendFeedback = 'Send feedback';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String themeSystem = 'System';
  static const String done = 'Done';

  // Notification Channels & Legacy Keys
  static const String eyeBreakChannelName = 'Eye Break Alerts';
  static const String eyeBreakChannelDesc = 'Reminders to rest eyes based on continuous screen time';
  static const String waterChannelName = 'Hydration Reminders';
  static const String waterChannelDesc = 'Periodic reminders to drink water';
  static const String sunlightChannelName = 'Sunlight Reminders';
  static const String sunlightChannelDesc = 'Reminders to get outdoor natural light';
  static const String movementChannelName = 'Movement Alerts';
  static const String movementChannelDesc = 'Reminders to break sedentary periods';
  static const String movementNotificationTitle = 'Time to Move & Stretch!';
  static const String movementNotificationBody = 'You have been seated for a while. Stand up, stretch your shoulders, and walk for 2 minutes!';
  static const String eyeStrainTitle = 'Eye Strain Protection';
  static const String currentScreenSession = 'Current Screen Session';
  static const String targetBreakInterval = 'Break Interval';
  static const String takeEyeBreakNow = 'Take 20s Eye Break';
  static const String waterIntakeTitle = 'Smart Hydration';
  static const String waterIntakeSubtitle = 'Daily Water Goal & Reminders';
  static const String waterIntakeDesc = 'Personalized water target based on your body weight and daily activity.';
  static const String movementDesc = 'Take short movement breaks during prolonged sitting and maintain good device posture.';
  static const String dailySteps = 'Daily Steps';
  static const String distanceWalked = 'Distance';
  static const String activeTime = 'Active Time';
  static const String healthConnectGuide = 'Sync Steps with Google Fit';
  static const String sedentaryAlertInterval = 'Inactivity Nudge';
  static const String recommendedWindow = 'Best Daylight Windows: 8-10 AM & 4-5 PM';

  // Units
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String settings = 'Settings';
  static const String minuteUnit = 'min';
  static const String minutesUnit = 'mins';
  static const String literUnit = 'L';
  static const String milliliterUnit = 'ml';
  static const String degreeUnit = '°';
  static const String percentageUnit = '%';
  static const String kgUnit = 'kg';
  static const String kmUnit = 'km';
  static const String stepsUnit = 'steps';
}
