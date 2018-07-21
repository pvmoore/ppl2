module ppl2.misc.tasks;

import ppl2.internal;

public:
//=============================================================================
void moduleRequired(string moduleName) {
    if(g_modulesRequested.contains(moduleName)) return;
    g_modulesRequested.add(moduleName);

    Task t = {
        Task.Enum.MODULE,
        moduleName, null
    };
    pushPriorityTask(t);
}
void defineRequired(string moduleName, string defineName) {
    string key = "%s|%s".format(moduleName, defineName);

    if(g_definesRequested.contains(key)) return;
    g_definesRequested.add(key);

    Task t = {
        Task.Enum.DEFINE,
        moduleName,
        defineName
    };
    pushTask(t);
}
void functionRequired(string moduleName, string funcName) {
    string key = "%s|%s".format(moduleName, funcName);

    if(g_functionsRequested.contains(key)) return;
    g_functionsRequested.add(key);

    Task t = {
        Task.Enum.FUNC,
        moduleName,
        funcName
    };
    pushTask(t);
}
//=============================================================================
struct Task {
    enum Enum { FUNC, DEFINE, MODULE }
    Enum type;

    string moduleName;
    string elementName;
}
int countTasks() {
    return g_taskQueue.length;
}
bool tasksAvailable() {
    return !g_taskQueue.empty;
}

Task popTask() {
    return g_taskQueue.pop();
}

void pushTask(Task t) {
    g_taskQueue.push(t);
}
void pushPriorityTask(Task t) {
    g_taskQueue.pushToFront(t);
}



