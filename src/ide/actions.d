module ide.actions;

import ide.internal;

enum ActionID : int {
    /// Menu items
    CONTEXT_MENU,
    HELP_MENU,

    FILE_EXIT,
    FILE_OPEN_PROJECT,

    HELP_ABOUT,

    ///
    PROJECT_VIEW_FILE_ACTIVATED,

    WINDOW_CAPTION_CHANGE,

    /// Toolbar
    TOOLBAR_BUILD_MODULE,
    TOOLBAR_BUILD_PROJECT,
    TOOLBAR_BUILD_OPT_PROJECT,

    ///
    PROJECT_OPEN
}
