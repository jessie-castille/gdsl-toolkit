/*
* generated by Xtext
*/
package gdsl.plugin.ui.labeling

import com.google.inject.Inject
import gdsl.plugin.gDSL.ConDecl
import gdsl.plugin.gDSL.DeclExport
import gdsl.plugin.gDSL.Val
import gdsl.plugin.gDSL.Ty
import gdsl.plugin.gDSL.Type
import org.eclipse.emf.edit.ui.provider.AdapterFactoryLabelProvider
import org.eclipse.jdt.ui.ISharedImages
import org.eclipse.jdt.ui.JavaUI
import org.eclipse.jface.viewers.StyledString
import org.eclipse.xtext.ui.label.DefaultEObjectLabelProvider

/**
 * Provides labels for a EObjects.
 * 
 * see http://www.eclipse.org/Xtext/documentation.html#labelProvider
 */
class GDSLLabelProvider extends DefaultEObjectLabelProvider {

	@Inject
	new(AdapterFactoryLabelProvider delegate) {
		super(delegate);
	}

	// Labels and icons can be computed like this:
	
//	def text(Greeting ele) {
//		'A greeting to ' + ele.name
//	}
//
//	def image(Greeting ele) {
//		'Greeting.gif'
//	}

	def text(DeclExport e){
		e.name.name
	}
	def image(DeclExport e){
		JavaUI.sharedImages.getImage(ISharedImages.IMG_OBJS_PRIVATE)
	}

	def text(Type t){
		var result = new StyledString()
		result.append(t.name)
		if(null != t.value){
			val style = StyledString.DECORATIONS_STYLER
			result.append(" (" + text(t.value) + ")", style)
		}
		return result
	}
	def String text(Ty t){
		var result = new StringBuilder()
		if(null != t.value){
			result.append(t.value)
		}
		if(null != t.typeRef){
			result.append(t.typeRef.name)
		}
		if(null != t.type){
			result.append(t.type)
		}
		if(null != t.elements && t.elements.length > 0){
			result.append(text(t.elements.get(0).value))
			var i = 1
			while(i < t.elements.length){
				result.append(", " + text(t.elements.get(i).value))
				i=i+1
			}
		}
		result.toString
	}
	def image(Type t){
		JavaUI.sharedImages.getImage(ISharedImages.IMG_OBJS_PROTECTED)
	}
	
	def text(ConDecl cd){
		var result = new StyledString()
		result.append(cd.name.conName)
		if(null != cd.ty){
			result.append(" : " + text(cd.ty), StyledString.COUNTER_STYLER)
		}
		return result
	}
	def image(ConDecl cd){
		JavaUI.sharedImages.getImage(ISharedImages.IMG_OBJS_IMPDECL)
	}
	
	def text(Val v){
		var result = new StyledString()
		result.append(v.name)
		val decPat = v.decPat
		if(null != decPat && decPat.length > 0){
			var bitPat = new StringBuilder()
			for(s : decPat){
				bitPat.append(" " + s)
			}
			result.append(" [" + bitPat.toString.trim + "]", StyledString.QUALIFIER_STYLER)
		}
		val attr = v.attr
		if(null != attr && attr.length > 0){
			result.append(" :", StyledString.COUNTER_STYLER)
			for(s : attr){
				result.append(" " + s, StyledString.COUNTER_STYLER)
			}
		}
		return result
	}
	def image(Val v){
		JavaUI.sharedImages.getImage(ISharedImages.IMG_OBJS_PUBLIC)
	}
	
}
