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
void defineRequired(string moduleName, string defineName, Type[] templateParams=null) {
    string key = "%s|%s".format(moduleName, defineName);
    if(templateParams) key ~= "<" ~ mangle(templateParams) ~ ">";

    if(g_definesRequested.contains(key)) return;
    g_definesRequested.add(key);

    Task t = {
        Task.Enum.DEFINE,
        moduleName,
        defineName,
        templateParams
    };
    pushTask(t);
}
void functionRequired(string moduleName, string funcName, Type[] templateParams=null) {
    string key = "%s|%s".format(moduleName, funcName);
    if(templateParams) key ~= "<" ~ mangle(templateParams) ~ ">";

    if(g_functionsRequested.contains(key)) return;
    g_functionsRequested.add(key);

    Task t = {
        Task.Enum.FUNC,
        moduleName,
        funcName,
        templateParams
    };
    pushTask(t);
}
//=============================================================================
struct Task {
    enum Enum { FUNC, DEFINE, MODULE }
    Enum type;

    string moduleName;
    string elementName;
    Type[] templateParams;
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



