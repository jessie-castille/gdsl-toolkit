package gdsl.plugin.preferences.plugin;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.ProjectScope;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.Path;
import org.eclipse.core.runtime.preferences.IEclipsePreferences;
import org.eclipse.core.runtime.preferences.IScopeContext;
import org.eclipse.core.runtime.preferences.InstanceScope;
import org.eclipse.emf.ecore.resource.Resource;

/**
 * Constant definitions for plug-in preferences
 */
public class GDSLPluginPreferences {
	public static final String PLUGIN_SCOPE = "gdsl.plugin";
	
	public static final String P_COMPILER_INVOCATION = "compilerInvocation";
	public static final String P_USE_TYPECHECKER = "useTypechecker";
	public static final String P_ITERATION_TYPECHECKER = "iterationTypechecker";
	
	public static final String D_COMPILER_INVOCATION = "/usr/bin/sml @SMLload=./gdslc-image";
	public static final boolean D_USE_TYPECHECKER = true;
	public static final int D_ITERATION_TYPECHEKCER = 2;
	
	public static final String P_OUTPUT_NAME = "outputName";
	public static final String P_HAS_PREFIX = "hasPrefix";
	public static final String P_PREFIX = "prefix";
	public static final String P_RUNTIME_TEMPLATES = "runtimeTemplates";
	
	public static final String D_OUTPUT_NAME = "gdsl-x86-rreil";
	public static final boolean D_HAS_PREFIX = false;
	public static final String D_PREFIX = "";
	public static final String D_RUNTIME_TEMPLATES = "detail/codegen/c1";
	
	public static String getCompilerInvocation(){
		return getPreferenceStore().get(P_COMPILER_INVOCATION, D_COMPILER_INVOCATION);
	}
	
	public static boolean isTypeCheckerEnabled(){
		return getPreferenceStore().getBoolean(P_USE_TYPECHECKER, D_USE_TYPECHECKER);
	}
	
	public static int getTypeCheckerIteration(){
		return getPreferenceStore().getInt(P_ITERATION_TYPECHECKER, D_ITERATION_TYPECHEKCER);
	}
	
	public static String getOutputName(Resource resource){
		return getProjectProperties(resource).get(P_OUTPUT_NAME, D_OUTPUT_NAME);
	}
	
	public static String getPrefix(Resource resource){
		IEclipsePreferences store = getProjectProperties(resource);
		if(store.getBoolean(P_HAS_PREFIX, D_HAS_PREFIX)){
			return store.get(P_PREFIX, D_PREFIX);
		}
		return null;
	}
	
	public static String getRuntimeTemplates(Resource resource){
		return getProjectProperties(resource).get(P_RUNTIME_TEMPLATES, D_RUNTIME_TEMPLATES);
	}
	
	public static IEclipsePreferences getProjectProperties(Resource resource){
		IPath resourcePath = new Path(resource.getURI().toPlatformString(true));
		IProject project = ResourcesPlugin.getWorkspace().getRoot().getFile(resourcePath).getProject();
		IScopeContext projectScope = new ProjectScope(project);
		return projectScope.getNode(PLUGIN_SCOPE);
	}
	
	public static IEclipsePreferences getPreferenceStore() {
		return InstanceScope.INSTANCE.getNode(PLUGIN_SCOPE);
	}
	
}
