module ppl2.misc.tasks;

import ppl2.internal;

public:
//=============================================================================

void functionRequired(string moduleName, string funcName) {
    string key = "%s|%s".format(moduleName, funcName);
    if(functionsRequested.contains(key)) return;
    functionsRequested.add(key);
    Task t = {
        Task.Type.FUNC,
        moduleName,
        funcName
    };
    pushTask(t);
}
void defineRequired(string moduleName, string defineName) {
    string key = "%s|%s".format(moduleName, defineName);
    if(definesRequested.contains(key)) return;
    definesRequested.add(key);
    Task t = {
        Task.Type.DEFINE,
        moduleName,
        defineName
    };
    pushTask(t);
}
void exportsRequired(string moduleName) {
    Task t = {
        Task.Type.EXPORTS,
        moduleName, null
    };
    pushPriorityTask(t);
}

struct Task {
    enum Type { FUNC, DEFINE, EXPORTS }
    Type type;

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



