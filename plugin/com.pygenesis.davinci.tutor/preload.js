const WorkflowIntegration = require("./WorkflowIntegration.node");

const PLUGIN_ID = "com.pygenesis.davinci.tutor";

window.PLUGIN_ID = PLUGIN_ID;

window.GetResolveInterface = function GetResolveInterface() {
  const isResolveInit = WorkflowIntegration.Initialize(PLUGIN_ID);
  if (!isResolveInit) {
    return null;
  }

  const resolveInterface = WorkflowIntegration.GetResolve();
  if (!resolveInterface) {
    return null;
  }

  return resolveInterface;
};

window.CleanupResolveInterface = function CleanupResolveInterface() {
  WorkflowIntegration.CleanUp();
};
