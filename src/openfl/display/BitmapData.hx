package openfl.display; #if !flash


import haxe.macro.Context;
import lime.app.Future;
import lime.app.Promise;
import lime.graphics.cairo.CairoExtend;
import lime.graphics.cairo.CairoFilter;
import lime.graphics.cairo.CairoImageSurface;
import lime.graphics.cairo.CairoPattern;
import lime.graphics.cairo.CairoSurface;
import lime.graphics.cairo.Cairo;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLRenderbuffer;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GL;
import lime.graphics.Image;
import lime.graphics.ImageChannel;
import lime.graphics.ImageBuffer;
import lime.math.ColorMatrix;
import lime.math.Rectangle in LimeRectangle;
import lime.math.Vector2;
import lime.utils.Float32Array;
import lime.utils.UInt8Array;
import openfl._internal.utils.PerlinNoise;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3D;
import openfl.errors.Error;
import openfl.errors.IOError;
import openfl.errors.TypeError;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import openfl.utils.Object;
import openfl.Vector;

#if (lime >= "7.0.0")
import lime._internal.graphics.ImageCanvasUtil; // TODO
import lime.graphics.RenderContext;
import lime.math.ARGB;
#else
import lime.graphics.opengl.WebGLContext;
import lime.graphics.utils.ImageCanvasUtil;
import lime.graphics.GLRenderContext;
import lime.math.color.ARGB;
#end

#if (js && html5)
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.ImageData;
import js.html.ImageElement;
import js.html.Uint8ClampedArray;
import js.Browser;
#end

#if lime_cairo
import openfl.display.CairoRenderer;
#end

#if gl_stats
import openfl._internal.renderer.opengl.stats.GLStats;
import openfl._internal.renderer.opengl.stats.DrawCallContext;
#end


/**
 * The BitmapData class lets you work with the data(pixels) of a Bitmap
 * object. You can use the methods of the BitmapData class to create
 * arbitrarily sized transparent or opaque bitmap images and manipulate them
 * in various ways at runtime. You can also access the BitmapData for a bitmap
 * image that you load with the `openfl.Assets` or 
 * `openfl.display.Loader` classes.
 *
 * This class lets you separate bitmap rendering operations from the
 * internal display updating routines of OpenFL. By manipulating a
 * BitmapData object directly, you can create complex images without incurring
 * the per-frame overhead of constantly redrawing the content from vector
 * data.
 *
 * The methods of the BitmapData class support effects that are not
 * available through the filters available to non-bitmap display objects.
 *
 * A BitmapData object contains an array of pixel data. This data can
 * represent either a fully opaque bitmap or a transparent bitmap that
 * contains alpha channel data. Either type of BitmapData object is stored as
 * a buffer of 32-bit integers. Each 32-bit integer determines the properties
 * of a single pixel in the bitmap.
 *
 * Each 32-bit integer is a combination of four 8-bit channel values(from
 * 0 to 255) that describe the alpha transparency and the red, green, and blue
 * (ARGB) values of the pixel.(For ARGB values, the most significant byte
 * represents the alpha channel value, followed by red, green, and blue.)
 *
 * The four channels(alpha, red, green, and blue) are represented as
 * numbers when you use them with the `BitmapData.copyChannel()`
 * method or the `DisplacementMapFilter.componentX` and
 * `DisplacementMapFilter.componentY` properties, and these numbers
 * are represented by the following constants in the BitmapDataChannel
 * class:
 *
 * 
 *  * `BitmapDataChannel.ALPHA`
 *  * `BitmapDataChannel.RED`
 *  * `BitmapDataChannel.GREEN`
 *  * `BitmapDataChannel.BLUE`
 * 
 *
 * You can attach BitmapData objects to a Bitmap object by using the
 * `bitmapData` property of the Bitmap object.
 *
 * You can use a BitmapData object to fill a Graphics object by using the
 * `Graphics.beginBitmapFill()` method.
 * 
 * You can also use a BitmapData object to perform batch tile rendering
 * using the `openfl.display.Tilemap` class.
 *
 * In Flash Player 10, the maximum size for a BitmapData object
 * is 8,191 pixels in width or height, and the total number of pixels cannot
 * exceed 16,777,215 pixels.(So, if a BitmapData object is 8,191 pixels wide,
 * it can only be 2,048 pixels high.) In Flash Player 9 and earlier, the limitation 
 * is 2,880 pixels in height and 2,880 in width.
 */

@:access(lime.graphics.opengl.GL)
@:access(lime.graphics.Image)
@:access(lime.graphics.ImageBuffer)
@:access(lime.math.Rectangle)
@:access(openfl.display3D.textures.TextureBase)
@:access(openfl.display3D.Context3D)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.DisplayObjectShader)
@:access(openfl.display.Graphics)
@:access(openfl.display.Shader)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Point)
@:access(openfl.geom.Rectangle)

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:autoBuild(openfl._internal.macros.AssetsMacro.embedBitmap())


class BitmapData implements IBitmapDrawable {
	
	
	@:noCompletion private static inline var __bufferStride = 14;
	@:noCompletion private static var __supportsBGRA:Null<Bool> = null;
	@:noCompletion private static var __tempVector:Vector2 = new Vector2 ();
	@:noCompletion private static var __textureFormat:Int;
	@:noCompletion private static var __textureInternalFormat:Int;
	
	
	/**
	 * The height of the bitmap image in pixels.
	 */
	public var height (default, null):Int;
	
	/**
	 * The Lime image that holds the pixels for the current image.
	 * 
	 * In Flash Player, this property is always `null`.
	 */
	public var image (default, null):Image;
	
	// #if !flash_doc_gen
	/**
	 * Defines whether the bitmap image is readable. Hardware-only bitmap images
	 * do not support `getPixels`, `setPixels` and other 
	 * BitmapData methods, though they can still be used inside a Bitmap object 
	 * or other display objects that do not need to modify the pixels.
	 * 
	 * As an exception to the rule, `bitmapData.draw` is supported for
	 * non-readable bitmap images.
	 * 
	 * Since non-readable bitmap images do not have a software image buffer, they
	 * will need to be recreated if the current hardware rendering context is lost.
	 */
	@:beta public var readable (default, null):Bool;
	// #end
	
	/**
	 * The rectangle that defines the size and location of the bitmap image. The
	 * top and left of the rectangle are 0; the width and height are equal to the
	 * width and height in pixels of the BitmapData object.
	 */
	public var rect (default, null):Rectangle;
	
	/**
	 * Defines whether the bitmap image supports per-pixel transparency. You can
	 * set this value only when you construct a BitmapData object by passing in
	 * `true` for the `transparent` parameter of the
	 * constructor. Then, after you create a BitmapData object, you can check
	 * whether it supports per-pixel transparency by determining if the value of
	 * the `transparent` property is `true`.
	 */
	public var transparent (default, null):Bool;
	
	/**
	 * The width of the bitmap image in pixels.
	 */
	public var width (default, null):Int;
	
	
	@:noCompletion private var __blendMode:BlendMode;
	@:noCompletion private var __buffer:GLBuffer;
	@:noCompletion private var __bufferColorTransform:ColorTransform;
	@:noCompletion private var __bufferContext:#if (lime >= "7.0.0") RenderContext #else GLRenderContext #end;
	@:noCompletion private var __bufferAlpha:Float;
	@:noCompletion private var __bufferData:Float32Array;
	@:noCompletion private var __framebuffer:GLFramebuffer;
	@:noCompletion private var __framebufferContext:#if (lime >= "7.0.0") RenderContext #else GLRenderContext #end;
	@:noCompletion private var __isMask:Bool;
	@:noCompletion private var __isValid:Bool;
	@:noCompletion private var __mask:DisplayObject;
	@:noCompletion private var __renderable:Bool;
	@:noCompletion private var __renderTransform:Matrix;
	@:noCompletion private var __scrollRect:Rectangle;
	@:noCompletion private var __stencilBuffer:GLRenderbuffer;
	@:noCompletion private var __surface:CairoSurface;
	@:noCompletion private var __texture:GLTexture;
	@:noCompletion private var __textureContext:#if (lime >= "7.0.0") RenderContext #else GLRenderContext #end;
	@:noCompletion private var __textureHeight:Int;
	@:noCompletion private var __textureVersion:Int;
	@:noCompletion private var __textureWidth:Int;
	@:noCompletion private var __transform:Matrix;
	@:noCompletion private var __uvRect:Rectangle;
	@:noCompletion private var __worldAlpha:Float;
	@:noCompletion private var __worldColorTransform:ColorTransform;
	@:noCompletion private var __worldTransform:Matrix;
	
	
	/**
	 * Creates a BitmapData object with a specified width and height. If you specify a value for 
	 * the `fillColor` parameter, every pixel in the bitmap is set to that color. 
	 * 
	 * By default, the bitmap is created as transparent, unless you pass the value `false`
	 * for the transparent parameter. After you create an opaque bitmap, you cannot change it 
	 * to a transparent bitmap. Every pixel in an opaque bitmap uses only 24 bits of color channel 
	 * information. If you define the bitmap as transparent, every pixel uses 32 bits of color 
	 * channel information, including an alpha transparency channel.
	 * 
	 * @param	width		The width of the bitmap image in pixels. 
	 * @param	height		The height of the bitmap image in pixels. 
	 * @param	transparent		Specifies whether the bitmap image supports per-pixel transparency. The default value is `true`(transparent). To create a fully transparent bitmap, set the value of the `transparent` parameter to `true` and the value of the `fillColor` parameter to 0x00000000(or to 0). Setting the `transparent` property to `false` can result in minor improvements in rendering performance.
	 * @param	fillColor		A 32-bit ARGB color value that you use to fill the bitmap image area. The default value is 0xFFFFFFFF(solid white).
	 */
	public function new (width:Int, height:Int, transparent:Bool = true, fillColor:UInt = 0xFFFFFFFF) {
		
		this.transparent = transparent;
		
		#if (neko || (js && html5))
		width = width == null ? 0 : width;
		height = height == null ? 0 : height;
		#end
		
		width = width < 0 ? 0 : width;
		height = height < 0 ? 0 : height;
		
		this.width = width;
		this.height = height;
		rect = new Rectangle (0, 0, width, height);
		
		__textureWidth = width;
		__textureHeight = height;
		
		if (width > 0 && height > 0) {
			
			if (transparent) {
				
				if ((fillColor & 0xFF000000) == 0) {
					
					fillColor = 0;
					
				}
				
			} else {
				
				fillColor = (0xFF << 24) | (fillColor & 0xFFFFFF);
				
			}
			
			fillColor = (fillColor << 8) | ((fillColor >> 24) & 0xFF);
			
			#if sys
			var buffer = new ImageBuffer (new UInt8Array (width * height * 4), width, height);
			buffer.format = BGRA32;
			buffer.premultiplied = true;
			
			image = new Image (buffer, 0, 0, width, height);
			
			if (fillColor != 0) {
				
				image.fillRect (image.rect, fillColor);
				
			}
			//#elseif (js && html5)
			//var buffer = new ImageBuffer (null, width, height);
			//var canvas:CanvasElement = cast Browser.document.createElement ("canvas");
			//buffer.__srcCanvas = canvas;
			//buffer.__srcContext = canvas.getContext ("2d");
			//
			//image = new Image (buffer, 0, 0, width, height);
			//image.type = CANVAS;
			//
			//if (fillColor != 0) {
				//
				//image.fillRect (image.rect, fillColor);
				//
			//}
			#else
			image = new Image (null, 0, 0, width, height, fillColor);
			#end
			
			image.transparent = transparent;
			
			__isValid = true;
			readable = true;
			
		}
		
		__renderTransform = new Matrix ();
		__worldAlpha = 1;
		__worldTransform = new Matrix ();
		__worldColorTransform = new ColorTransform ();
		__renderable = true;
		
	}
	
	
	/**
	 * Takes a source image and a filter object and generates the filtered image. 
	 * 
	 * This method relies on the behavior of built-in filter objects, which determine the 
	 * destination rectangle that is affected by an input source rectangle.
	 * 
	 * After a filter is applied, the resulting image can be larger than the input image. 
	 * For example, if you use a BlurFilter class to blur a source rectangle of(50,50,100,100) 
	 * and a destination point of(10,10), the area that changes in the destination image is 
	 * larger than(10,10,60,60) because of the blurring. This happens internally during the 
	 * applyFilter() call.
	 * 
	 * If the `sourceRect` parameter of the sourceBitmapData parameter is an 
	 * interior region, such as(50,50,100,100) in a 200 x 200 image, the filter uses the source 
	 * pixels outside the `sourceRect` parameter to generate the destination rectangle.
	 * 
	 * If the BitmapData object and the object specified as the `sourceBitmapData` 
	 * parameter are the same object, the application uses a temporary copy of the object to 
	 * perform the filter. For best performance, avoid this situation.
	 * 
	 * @param	sourceBitmapData		The input bitmap image to use. The source image can be a different BitmapData object or it can refer to the current BitmapData instance.
	 * @param	sourceRect		A rectangle that defines the area of the source image to use as input.
	 * @param	destPoint		The point within the destination image(the current BitmapData instance) that corresponds to the upper-left corner of the source rectangle. 
	 * @param	filter		The filter object that you use to perform the filtering operation. 
	 */
	public function applyFilter (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, filter:BitmapFilter):Void {
		
		if (!readable || sourceBitmapData == null || !sourceBitmapData.readable) return;
		
		// TODO: Ways to optimize this?
		
		var needSecondBitmapData = filter.__needSecondBitmapData;
		var needCopyOfOriginal = filter.__preserveObject;
		
		var bitmapData2 = null;
		var bitmapData3 = null;
		
		if (needSecondBitmapData) {
			bitmapData2 = new BitmapData (width, height, true, 0);
		} else {
			bitmapData2 = this;
		}
		
		if (needCopyOfOriginal) {
			bitmapData3 = new BitmapData (width, height, true, 0);
		}
		
		if (filter.__preserveObject) {
			bitmapData3.copyPixels (this, rect, destPoint);
		}
		
		var lastBitmap = filter.__applyFilter (bitmapData2, this, sourceRect, destPoint);
		
		if (filter.__preserveObject) {
			lastBitmap.draw (bitmapData3, null, null);
		}
		
		if (needSecondBitmapData && lastBitmap == bitmapData2) {
			
			bitmapData2.image.version = image.version;
			image = bitmapData2.image;
			
		}
		
		image.dirty = true;
		image.version++;
		
	}
	
	
	/**
	 * Returns a new BitmapData object that is a clone of the original instance with an exact copy of the contained bitmap. 
	 * @return		A new BitmapData object that is identical to the original.
	 */
	public function clone ():BitmapData {
		
		var bitmapData;
		
		if (!__isValid) {
			
			bitmapData = new BitmapData (width, height, transparent, 0);
			
		} else if (!readable && image == null) {
			
			bitmapData = new BitmapData (0, 0, transparent, 0);
			
			bitmapData.width = width;
			bitmapData.height = height;
			bitmapData.__textureWidth = __textureWidth;
			bitmapData.__textureHeight = __textureHeight;
			bitmapData.rect.copyFrom (rect);
			
			bitmapData.__framebuffer = __framebuffer;
			bitmapData.__framebufferContext = __framebufferContext;
			bitmapData.__texture = __texture;
			bitmapData.__textureContext = __textureContext;
			bitmapData.__isValid = true;
			
		} else {
			
			bitmapData = BitmapData.fromImage (image.clone (), transparent);
			
		}
		
		bitmapData.__worldTransform.copyFrom (__worldTransform);
		bitmapData.__renderTransform.copyFrom (__renderTransform);
		
		return bitmapData;
		
	}
	
	
	/**
	 * Adjusts the color values in a specified area of a bitmap image by using a `ColorTransform`
	 * object. If the rectangle matches the boundaries of the bitmap image, this method transforms the color 
	 * values of the entire image. 
	 * @param	rect		A Rectangle object that defines the area of the image in which the ColorTransform object is applied.
	 * @param	colorTransform		A ColorTransform object that describes the color transformation values to apply.
	 */
	public function colorTransform (rect:Rectangle, colorTransform:ColorTransform):Void {
		
		if (!readable) return;
		
		image.colorTransform (rect.__toLimeRectangle (), colorTransform.__toLimeColorMatrix ());
		
	}
	
	
	/**
	 * Compares two BitmapData objects. If the two BitmapData objects have the same dimensions (width and height), the method returns a new BitmapData object, in which each pixel is the "difference" between the pixels in the two source objects:
	 * 
	 * - If two pixels are equal, the difference pixel is 0x00000000.
	 * - If two pixels have different RGB values (ignoring the alpha value), the difference pixel is 0xFFRRGGBB where RR/GG/BB are the individual difference values between red, green, and blue channels. Alpha channel differences are ignored in this case.
	 * - If only the alpha channel value is different, the pixel value is 0xZZFFFFFF, where ZZ is the difference in the alpha value.
	 * 
	 * @param	otherBitmapData The BitmapData object to compare with the source BitmapData object.
	 * @return If the two BitmapData objects have the same dimensions (width and height), the method returns a new BitmapData object that has the difference between the two objects (see the main discussion).If the BitmapData objects are equivalent, the method returns the number 0. If no argument is passed or if the argument is not a BitmapData object, the method returns -1. If either BitmapData object has been disposed of, the method returns -2. If the widths of the BitmapData objects are not equal, the method returns the number -3. If the heights of the BitmapData objects are not equal, the method returns the number -4.
	 */
	public function compare (otherBitmapData:BitmapData):Dynamic {
		
		if (otherBitmapData == this) {
			
			return 0;
			
		} else if (otherBitmapData == null) {
			
			return -1;
			
		} else if (readable == false || otherBitmapData.readable == false) {
			
			return -2;
			
		} else if (width != otherBitmapData.width) {
			
			return -3;
			
		} else if (height != otherBitmapData.height) {
			
			return -4;
			
		}
		
		if (image != null && otherBitmapData.image != null && image.format == otherBitmapData.image.format) {
			
			var bytes = image.data;
			var otherBytes = otherBitmapData.image.data;
			var equal = true;
			
			for (i in 0...bytes.length) {
				
				if (bytes[i] != otherBytes[i]) {
					
					equal = false;
					break;
					
				}
			}
			
			if (equal) {
				
				return 0;
				
			}
			
		}
		
		var bitmapData = null;
		var foundDifference, pixel:ARGB, otherPixel:ARGB, comparePixel:ARGB, r, g, b, a;
		
		for (y in 0...height) {
			
			for (x in 0...width) {
				
				foundDifference = false;
				
				pixel = getPixel32 (x, y);
				otherPixel = otherBitmapData.getPixel32 (x, y);
				comparePixel = 0;
				
				if (pixel != otherPixel) {
					
					r = pixel.r - otherPixel.r;
					g = pixel.g - otherPixel.g;
					b = pixel.b - otherPixel.b;
					
					if (r < 0) r *= -1;
					if (g < 0) g *= -1;
					if (b < 0) b *= -1;
					
					if (r == 0 && g == 0 && b == 0) {
						
						a = pixel.a - otherPixel.a;
						
						if (a != 0) {
							
							comparePixel.r = 0xFF;
							comparePixel.g = 0xFF;
							comparePixel.b = 0xFF;
							comparePixel.a = a;
							
							foundDifference = true;
							
						}
						
					} else {
						
						comparePixel.r = r;
						comparePixel.g = g;
						comparePixel.b = b;
						comparePixel.a = 0xFF;
						
						foundDifference = true;
						
					}
					
				}
				
				if (foundDifference) {
					
					if (bitmapData == null) {
						
						bitmapData = new BitmapData (width, height, transparent || otherBitmapData.transparent, 0x00000000);
						
					}
					
					bitmapData.setPixel32 (x, y, comparePixel);
					
				}
				
			}
			
		}
		
		if (bitmapData == null) {
			
			return 0;
			
		}
		
		return bitmapData;
		
	}
	
	
	/**
	 * Transfers data from one channel of another BitmapData object or the
	 * current BitmapData object into a channel of the current BitmapData object.
	 * All of the data in the other channels in the destination BitmapData object
	 * are preserved.
	 *
	 * The source channel value and destination channel value can be one of
	 * following values: 
	 *
	 * 
	 *  * `BitmapDataChannel.RED`
	 *  * `BitmapDataChannel.GREEN`
	 *  * `BitmapDataChannel.BLUE`
	 *  * `BitmapDataChannel.ALPHA`
	 * 
	 * 
	 * @param sourceBitmapData The input bitmap image to use. The source image
	 *                         can be a different BitmapData object or it can
	 *                         refer to the current BitmapData object.
	 * @param sourceRect       The source Rectangle object. To copy only channel
	 *                         data from a smaller area within the bitmap,
	 *                         specify a source rectangle that is smaller than
	 *                         the overall size of the BitmapData object.
	 * @param destPoint        The destination Point object that represents the
	 *                         upper-left corner of the rectangular area where
	 *                         the new channel data is placed. To copy only
	 *                         channel data from one area to a different area in
	 *                         the destination image, specify a point other than
	 *                        (0,0).
	 * @param sourceChannel    The source channel. Use a value from the
	 *                         BitmapDataChannel class
	 *                        (`BitmapDataChannel.RED`,
	 *                         `BitmapDataChannel.BLUE`,
	 *                         `BitmapDataChannel.GREEN`,
	 *                         `BitmapDataChannel.ALPHA`).
	 * @param destChannel      The destination channel. Use a value from the
	 *                         BitmapDataChannel class
	 *                        (`BitmapDataChannel.RED`,
	 *                         `BitmapDataChannel.BLUE`,
	 *                         `BitmapDataChannel.GREEN`,
	 *                         `BitmapDataChannel.ALPHA`).
	 * @throws TypeError The sourceBitmapData, sourceRect or destPoint are null.
	 */
	public function copyChannel (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, sourceChannel:BitmapDataChannel, destChannel:BitmapDataChannel):Void {
		
		if (!readable) return;
		
		var sourceChannel = switch (sourceChannel) {
			
			case 1: ImageChannel.RED;
			case 2: ImageChannel.GREEN;
			case 4: ImageChannel.BLUE;
			case 8: ImageChannel.ALPHA;
			default: return;
			
		}
		
		var destChannel = switch (destChannel) {
			
			case 1: ImageChannel.RED;
			case 2: ImageChannel.GREEN;
			case 4: ImageChannel.BLUE;
			case 8: ImageChannel.ALPHA;
			default: return;
			
		}
		
		image.copyChannel (sourceBitmapData.image, sourceRect.__toLimeRectangle (), destPoint.__toLimeVector2 (), sourceChannel, destChannel);
		
	}
	
	
	/**
	 * Provides a fast routine to perform pixel manipulation between images with
	 * no stretching, rotation, or color effects. This method copies a
	 * rectangular area of a source image to a rectangular area of the same size
	 * at the destination point of the destination BitmapData object.
	 *
	 * If you include the `alphaBitmap` and `alphaPoint`
	 * parameters, you can use a secondary image as an alpha source for the
	 * source image. If the source image has alpha data, both sets of alpha data
	 * are used to composite pixels from the source image to the destination
	 * image. The `alphaPoint` parameter is the point in the alpha
	 * image that corresponds to the upper-left corner of the source rectangle.
	 * Any pixels outside the intersection of the source image and alpha image
	 * are not copied to the destination image.
	 *
	 * The `mergeAlpha` property controls whether or not the alpha
	 * channel is used when a transparent image is copied onto another
	 * transparent image. To copy pixels with the alpha channel data, set the
	 * `mergeAlpha` property to `true`. By default, the
	 * `mergeAlpha` property is `false`.
	 * 
	 * @param sourceBitmapData The input bitmap image from which to copy pixels.
	 *                         The source image can be a different BitmapData
	 *                         instance, or it can refer to the current
	 *                         BitmapData instance.
	 * @param sourceRect       A rectangle that defines the area of the source
	 *                         image to use as input.
	 * @param destPoint        The destination point that represents the
	 *                         upper-left corner of the rectangular area where
	 *                         the new pixels are placed.
	 * @param alphaBitmapData  A secondary, alpha BitmapData object source.
	 * @param alphaPoint       The point in the alpha BitmapData object source
	 *                         that corresponds to the upper-left corner of the
	 *                         `sourceRect` parameter.
	 * @param mergeAlpha       To use the alpha channel, set the value to
	 *                         `true`. To copy pixels with no alpha
	 *                         channel, set the value to `false`.
	 * @throws TypeError The sourceBitmapData, sourceRect, destPoint are null.
	 */
	public function copyPixels (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, alphaBitmapData:BitmapData = null, alphaPoint:Point = null, mergeAlpha:Bool = false):Void {
		
		if (!readable || sourceBitmapData == null) return;
		
		if (alphaPoint != null) {
			
			__tempVector.x = alphaPoint.x;
			__tempVector.y = alphaPoint.y;
			
		}
		
		image.copyPixels (sourceBitmapData.image, sourceRect.__toLimeRectangle (), destPoint.__toLimeVector2 (), alphaBitmapData != null ? alphaBitmapData.image : null, alphaPoint != null ? __tempVector : null, mergeAlpha);
		
	}
	
	
	// @:noCompletion @:dox(hide) @:require(flash11_4) public function copyPixelsToByteArray (rect:Rectangle, data:ByteArray):Void;
	
	
	/**
	 * Frees memory that is used to store the BitmapData object.
	 *
	 * When the `dispose()` method is called on an image, the width
	 * and height of the image are set to 0. All subsequent calls to methods or
	 * properties of this BitmapData instance fail, and an exception is thrown.
	 * 
	 *
	 * `BitmapData.dispose()` releases the memory occupied by the
	 * actual bitmap data, immediately(a bitmap can consume up to 64 MB of
	 * memory). After using `BitmapData.dispose()`, the BitmapData
	 * object is no longer usable and an exception may be thrown if
	 * you call functions on the BitmapData object. However,
	 * `BitmapData.dispose()` does not garbage collect the BitmapData
	 * object(approximately 128 bytes); the memory occupied by the actual
	 * BitmapData object is released at the time the BitmapData object is
	 * collected by the garbage collector.
	 * 
	 */
	public function dispose ():Void {
		
		image = null;
		
		width = 0;
		height = 0;
		rect = null;
		
		__isValid = false;
		readable = false;
		
		__surface = null;
		
		__buffer = null;
		__framebuffer = null;
		__framebufferContext = null;
		__texture = null;
		__textureContext = null;
		
		//if (__texture != null) {
			//
			//var renderer = @:privateAccess Lib.current.stage.__renderer;
			//
			//if(renderer != null) {
				//
				//var renderer = @:privateAccess renderer.renderer;
				//var gl = renderer.__gl;
				//
				//if (gl != null) {
					//
					//gl.deleteTexture (__texture);
					//__texture = null;
					//
				//}
				//
			//}
			//
		//}
		
	}
	
	
	/**
	 * Frees the backing Lime image buffer, if possible.
	 * 
	 * When using a software renderer, such as Flash Player or desktop targets
	 * without OpenGL, the software buffer will be retained so that the BitmapData
	 * will work properly. When using a hardware renderer, the Lime image
	 * buffer will be available to garbage collection after a hardware texture
	 * has been created internally.
	 * 
	 * `BitmapData.disposeImage()` will immediately change the value of 
	 * the `readable` property to `false`.
	 */
	@:beta public function disposeImage ():Void {
		
		readable = false;
		
	}
	
	
	/**
	 * Draws the `source` display object onto the bitmap image, using
	 * the OpenFL software renderer. You can specify `matrix`,
	 * `colorTransform`, `blendMode`, and a destination
	 * `clipRect` parameter to control how the rendering performs.
	 * Optionally, you can specify whether the bitmap should be smoothed when
	 * scaled(this works only if the source object is a BitmapData object).
	 *
	 * The source display object does not use any of its applied
	 * transformations for this call. It is treated as it exists in the library
	 * or file, with no matrix transform, no color transform, and no blend mode.
	 * To draw a display object(such as a movie clip) by using its own transform
	 * properties, you can copy its `transform` property object to the
	 * `transform` property of the Bitmap object that uses the
	 * BitmapData object.
	 * 
	 * @param source         The display object or BitmapData object to draw to
	 *                       the BitmapData object.(The DisplayObject and
	 *                       BitmapData classes implement the IBitmapDrawable
	 *                       interface.)
	 * @param matrix         A Matrix object used to scale, rotate, or translate
	 *                       the coordinates of the bitmap. If you do not want to
	 *                       apply a matrix transformation to the image, set this
	 *                       parameter to an identity matrix, created with the
	 *                       default `new Matrix()` constructor, or
	 *                       pass a `null` value.
	 * @param colorTransform A ColorTransform object that you use to adjust the
	 *                       color values of the bitmap. If no object is
	 *                       supplied, the bitmap image's colors are not
	 *                       transformed. If you must pass this parameter but you
	 *                       do not want to transform the image, set this
	 *                       parameter to a ColorTransform object created with
	 *                       the default `new ColorTransform()`
	 *                       constructor.
	 * @param blendMode      A string value, from the openfl.display.BlendMode
	 *                       class, specifying the blend mode to be applied to
	 *                       the resulting bitmap.
	 * @param clipRect       A Rectangle object that defines the area of the
	 *                       source object to draw. If you do not supply this
	 *                       value, no clipping occurs and the entire source
	 *                       object is drawn.
	 * @param smoothing      A Boolean value that determines whether a BitmapData
	 *                       object is smoothed when scaled or rotated, due to a
	 *                       scaling or rotation in the `matrix`
	 *                       parameter. The `smoothing` parameter only
	 *                       applies if the `source` parameter is a
	 *                       BitmapData object. With `smoothing` set
	 *                       to `false`, the rotated or scaled
	 *                       BitmapData image can appear pixelated or jagged. For
	 *                       example, the following two images use the same
	 *                       BitmapData object for the `source`
	 *                       parameter, but the `smoothing` parameter
	 *                       is set to `true` on the left and
	 *                       `false` on the right:
	 *
	 *                       Drawing a bitmap with `smoothing` set
	 *                       to `true` takes longer than doing so with
	 *                       `smoothing` set to
	 *                       `false`.
	 * @throws ArgumentError The `source` parameter is not a
	 *                       BitmapData or DisplayObject object.
	 * @throws ArgumentError The source is null or not a valid IBitmapDrawable
	 *                       object.
	 * @throws SecurityError The `source` object and(in the case of a
	 *                       Sprite or MovieClip object) all of its child objects
	 *                       do not come from the same domain as the caller, or
	 *                       are not in a content that is accessible to the
	 *                       caller by having called the
	 *                       `Security.allowDomain()` method. This
	 *                       restriction does not apply to AIR content in the
	 *                       application security sandbox.
	 */
	public function draw (source:IBitmapDrawable, matrix:Matrix = null, colorTransform:ColorTransform = null, blendMode:BlendMode = null, clipRect:Rectangle = null, smoothing:Bool = false):Void {
		
		if (source == null) return;
		
		source.__update (false, true);
		
		var transform = Matrix.__pool.get ();
		
		transform.copyFrom (source.__renderTransform);
		transform.invert ();
		
		if (matrix != null) {
			
			transform.concat (matrix);
			
		}
		
		var clipMatrix = null;
		
		if (clipRect != null) {
			
			clipMatrix = Matrix.__pool.get ();
			clipMatrix.copyFrom (transform);
			clipMatrix.invert ();
			
		}
		
		var _colorTransform = new ColorTransform ();
		_colorTransform.__copyFrom (source.__worldColorTransform);
		_colorTransform.__invert ();
		
		if (!readable) {
			
			if (__textureContext == null) {
				
				// TODO: Some way to select current GL context for renderer?
				#if (lime >= "7.0.0")
				__textureContext = lime.app.Application.current.window.context;
				#else
				__textureContext = GL.context;
				#end
				
			}
			
			if (colorTransform != null) {
				
				_colorTransform.__combine (colorTransform);
				
			}
			
			var renderer = new OpenGLRenderer (openfl.Lib.current.stage.context3D, this);
			renderer.__allowSmoothing = smoothing;
			renderer.__setBlendMode (blendMode);
			
			renderer.__worldTransform = transform;
			renderer.__worldAlpha = 1 / source.__worldAlpha;
			renderer.__worldColorTransform = _colorTransform;
			
			renderer.__resize (width, height);
			
			if (clipRect != null) {
				
				renderer.__pushMaskRect (clipRect, clipMatrix);
				
			}
			
			__drawGL (source, renderer);
			
			if (clipRect != null) {
				
				renderer.__popMaskRect ();
				Matrix.__pool.release (clipMatrix);
				
			}
			
		} else {
			
			#if ((js && html5) || lime_cairo)
			
			if (colorTransform != null) {
				
				var bounds = Rectangle.__pool.get ();
				var boundsMatrix = Matrix.__pool.get ();
				
				source.__getBounds (bounds, boundsMatrix);
				
				var width:Int = Math.ceil (bounds.width);
				var height:Int = Math.ceil (bounds.height);
				
				boundsMatrix.tx = -bounds.x;
				boundsMatrix.ty = -bounds.y;
				
				var copy = new BitmapData (width, height, true, 0);
				copy.draw (source, boundsMatrix);
				
				copy.colorTransform (copy.rect, colorTransform);
				copy.__renderTransform.identity ();
				copy.__renderTransform.tx = bounds.x;
				copy.__renderTransform.ty = bounds.y;
				copy.__renderTransform.concat (source.__renderTransform);
				copy.__worldAlpha = source.__worldAlpha;
				copy.__worldColorTransform.__copyFrom (source.__worldColorTransform);
				source = copy;
				
				Rectangle.__pool.release (bounds);
				Matrix.__pool.release (boundsMatrix);
				
			}
			
			#if (js && html5)
			ImageCanvasUtil.convertToCanvas (image);
			var renderer = new CanvasRenderer (image.buffer.__srcContext);
			#else
			var renderer = new CairoRenderer (new Cairo (getSurface ()));
			#end
			
			renderer.__allowSmoothing = smoothing;
			renderer.__setBlendMode (blendMode);
			
			renderer.__worldTransform = transform;
			renderer.__worldAlpha = 1 / source.__worldAlpha;
			renderer.__worldColorTransform = _colorTransform;
			
			if (clipRect != null) {
				
				renderer.__pushMaskRect (clipRect, clipMatrix);
				
			}
			
			#if (js && html5)
			__drawCanvas (source, renderer);
			#else
			__drawCairo (source, renderer);
			#end
			
			if (clipRect != null) {
				
				renderer.__popMaskRect ();
				Matrix.__pool.release (clipMatrix);
				
			}
			
			#end
			
		}
		
		Matrix.__pool.release (transform);
		
	}
	
	
	public function drawWithQuality (source:IBitmapDrawable, matrix:Matrix = null, colorTransform:ColorTransform = null, blendMode:BlendMode = null, clipRect:Rectangle = null, smoothing:Bool = false, quality:StageQuality = null):Void {
		
		draw (source, matrix, colorTransform, blendMode, clipRect, quality != LOW ? smoothing : false);
		
	}
	
	
	public function encode (rect:Rectangle, compressor:Object, byteArray:ByteArray = null):ByteArray {
		
		if (!readable || rect == null) return byteArray = null;
		if (byteArray == null) byteArray = new ByteArray();
		
		var image = this.image;
		
		if (!rect.equals (this.rect)) {
			
			var matrix = Matrix.__pool.get ();
			matrix.tx = Math.round (-rect.x);
			matrix.ty = Math.round (-rect.y);
			
			var bitmapData = new BitmapData (Math.ceil (rect.width), Math.ceil (rect.height), true, 0);
			bitmapData.draw (this, matrix);
			
			image = bitmapData.image;
			
			Matrix.__pool.release (matrix);
			
		}
		
		if (Std.is (compressor, PNGEncoderOptions)) {
			
			byteArray.writeBytes (ByteArray.fromBytes (image.encode (#if (lime >= "7.0.0") PNG #else "png" #end)));
			return byteArray;
			
		} else if (Std.is (compressor, JPEGEncoderOptions)) {
			
			byteArray.writeBytes (ByteArray.fromBytes (image.encode (#if (lime >= "7.0.0") JPEG #else "jpg" #end, cast (compressor, JPEGEncoderOptions).quality)));
			return byteArray;
			
		}
		
		return byteArray = null;
		
	}
	
	
	/**
	 * Fills a rectangular area of pixels with a specified ARGB color.
	 * 
	 * @param rect  The rectangular area to fill.
	 * @param color The ARGB color value that fills the area. ARGB colors are
	 *              often specified in hexadecimal format; for example,
	 *              0xFF336699.
	 * @throws TypeError The rect is null.
	 */
	public function fillRect (rect:Rectangle, color:Int):Void {
		
		__fillRect (rect, color, true);
		
	}
	
	
	/**
	 * Performs a flood fill operation on an image starting at an(_x_,
	 * _y_) coordinate and filling with a certain color. The
	 * `floodFill()` method is similar to the paint bucket tool in
	 * various paint programs. The color is an ARGB color that contains alpha
	 * information and color information.
	 * 
	 * @param x     The _x_ coordinate of the image.
	 * @param y     The _y_ coordinate of the image.
	 * @param color The ARGB color to use as a fill.
	 */
	public function floodFill (x:Int, y:Int, color:Int):Void {
		
		if (!readable) return;
		image.floodFill (x, y, color, ARGB32);
		
	}
	
	
	#if (!openfl_doc_gen || (!js && !html5 && !flash_doc_gen))
	public static function fromBase64 (base64:String, type:String):BitmapData {
		
		#if (js && html5)
		return null;
		#else
		var bitmapData = new BitmapData (0, 0, true, 0);
		bitmapData.__fromBase64 (base64, type);
		return bitmapData;
		#end
		
	}
	#end
	
	
	#if (!openfl_doc_gen || (!js && !html5 && !flash_doc_gen))
	public static function fromBytes (bytes:ByteArray, rawAlpha:ByteArray = null):BitmapData {
		
		#if (js && html5)
		return null;
		#else
		var bitmapData = new BitmapData (0, 0, true, 0);
		bitmapData.__fromBytes (bytes, rawAlpha);
		return bitmapData;
		#end
		
	}
	#end
	
	
	#if (js && html5)
	public static function fromCanvas (canvas:CanvasElement, transparent:Bool = true):BitmapData {
		
		if (canvas == null) return null;
		
		var bitmapData = new BitmapData (0, 0, transparent, 0);
		bitmapData.__fromImage (Image.fromCanvas (canvas));
		bitmapData.image.transparent = transparent;
		return bitmapData;
		
	}
	#end
	
	
	#if (!openfl_doc_gen || (!js && !html5 && !flash_doc_gen))
	public static function fromFile (path:String):BitmapData {
		
		#if (js && html5)
		return null;
		#else
		var bitmapData = new BitmapData (0, 0, true, 0);
		bitmapData.__fromFile (path);
		return bitmapData;
		#end
		
	}
	#end
	
	
	public static function fromImage (image:Image, transparent:Bool = true):BitmapData {
		
		if (image == null || image.buffer == null) return null;
		
		var bitmapData = new BitmapData (0, 0, transparent, 0);
		bitmapData.__fromImage (image);
		bitmapData.image.transparent = transparent;
		return bitmapData;
		
	}
	
	
	public static function fromTexture (texture:TextureBase):BitmapData {
		
		if (texture == null) return null;
		
		var bitmapData = new BitmapData (texture.__width, texture.__height, true, 0);
		bitmapData.readable = false;
		bitmapData.__texture = texture.__textureID;
		bitmapData.__textureContext = texture.__textureContext;
		bitmapData.image = null;
		return bitmapData;
		
	}
	
	
	/**
	 * Determines the destination rectangle that the `applyFilter()`
	 * method call affects, given a BitmapData object, a source rectangle, and a
	 * filter object.
	 *
	 * For example, a blur filter normally affects an area larger than the
	 * size of the original image. A 100 x 200 pixel image that is being filtered
	 * by a default BlurFilter instance, where `blurX = blurY = 4`
	 * generates a destination rectangle of `(-2,-2,104,204)`. The
	 * `generateFilterRect()` method lets you find out the size of
	 * this destination rectangle in advance so that you can size the destination
	 * image appropriately before you perform a filter operation.
	 *
	 * Some filters clip their destination rectangle based on the source image
	 * size. For example, an inner `DropShadow` does not generate a
	 * larger result than its source image. In this API, the BitmapData object is
	 * used as the source bounds and not the source `rect`
	 * parameter.
	 * 
	 * @param sourceRect A rectangle defining the area of the source image to use
	 *                   as input.
	 * @param filter     A filter object that you use to calculate the
	 *                   destination rectangle.
	 * @return A destination rectangle computed by using an image, the
	 *         `sourceRect` parameter, and a filter.
	 * @throws TypeError The sourceRect or filter are null.
	 */
	public function generateFilterRect (sourceRect:Rectangle, filter:BitmapFilter):Rectangle {
		
		return sourceRect.clone ();
		
	}
	
	
	@:dox(hide) public function getBuffer (context:Context3D):GLBuffer {
		
		
		var gl = context.__gl;
		
		if (__buffer == null || __bufferContext != context.__context) {
			
			#if openfl_power_of_two
			
			var newWidth = 1;
			var newHeight = 1;
			
			while (newWidth < width) {
				
				newWidth <<= 1;
				
			}
			
			while (newHeight < height) {
				
				newHeight <<= 1;
				
			}
			
			__uvRect = new Rectangle (0, 0, newWidth, newHeight);
			
			var uvWidth = width / newWidth;
			var uvHeight = height / newHeight;
			
			__textureWidth = newWidth;
			__textureHeight = newHeight;
			
			#else
			
			__uvRect = new Rectangle (0, 0, width, height);
			
			var uvWidth = 1;
			var uvHeight = 1;
			
			#end
			
			//__bufferData = new Float32Array ([
				//
				//width, height, 0, uvWidth, uvHeight, alpha, (color transform, color offset...)
				//0, height, 0, 0, uvHeight, alpha, (color transform, color offset...)
				//width, 0, 0, uvWidth, 0, alpha, (color transform, color offset...)
				//0, 0, 0, 0, 0, alpha, (color transform, color offset...)
				//
				//
			//]);
			
			//[ colorTransform.redMultiplier, 0, 0, 0, 0, colorTransform.greenMultiplier, 0, 0, 0, 0, colorTransform.blueMultiplier, 0, 0, 0, 0, colorTransform.alphaMultiplier ];
			//[ colorTransform.redOffset / 255, colorTransform.greenOffset / 255, colorTransform.blueOffset / 255, colorTransform.alphaOffset / 255 ]
			
			__bufferData = new Float32Array (__bufferStride * 4);
			
			__bufferData[0] = width;
			__bufferData[1] = height;
			__bufferData[3] = uvWidth;
			__bufferData[4] = uvHeight;
			__bufferData[__bufferStride + 1] = height;
			__bufferData[__bufferStride + 4] = uvHeight;
			__bufferData[__bufferStride * 2] = width;
			__bufferData[__bufferStride * 2 + 3] = uvWidth;
			
			// for (i in 0...4) {
				
			// 	__bufferData[__bufferStride * i + 5] = alpha;
				
			// 	if (colorTransform != null) {
					
			// 		__bufferData[__bufferStride * i + 6] = colorTransform.redMultiplier;
			// 		__bufferData[__bufferStride * i + 7] = colorTransform.greenMultiplier;
			// 		__bufferData[__bufferStride * i + 8] = colorTransform.blueMultiplier;
			// 		__bufferData[__bufferStride * i + 9] = colorTransform.alphaMultiplier;
			// 		__bufferData[__bufferStride * i + 10] = colorTransform.redOffset / 255;
			// 		__bufferData[__bufferStride * i + 11] = colorTransform.greenOffset / 255;
			// 		__bufferData[__bufferStride * i + 12] = colorTransform.blueOffset / 255;
			// 		__bufferData[__bufferStride * i + 13] = colorTransform.alphaOffset / 255;
					
			// 	}
				
			// }
			
			// __bufferAlpha = alpha;
			// __bufferColorTransform = colorTransform != null ? colorTransform.__clone () : null;
			__bufferContext = context.__context;
			__buffer = gl.createBuffer ();
			
			context.__bindBuffer (gl.ARRAY_BUFFER, __buffer);
			gl.bufferData (gl.ARRAY_BUFFER, __bufferData, gl.STATIC_DRAW);
			//gl.bindBuffer (gl.ARRAY_BUFFER, null);
			
		} else {
			
			// var dirty = false;
			
			// if (__bufferAlpha != alpha) {
				
			// 	dirty = true;
				
			// 	for (i in 0...4) {
					
			// 		__bufferData[__bufferStride * i + 5] = alpha;
					
			// 	}
				
			// 	__bufferAlpha = alpha;
				
			// }
			
			// if ((__bufferColorTransform == null && colorTransform != null) || (__bufferColorTransform != null && !__bufferColorTransform.__equals (colorTransform))) {
				
			// 	dirty = true;
				
			// 	if (colorTransform != null) {
					
			// 		if (__bufferColorTransform == null) {
			// 			__bufferColorTransform = colorTransform.__clone ();
			// 		} else {
			// 			__bufferColorTransform.__copyFrom (colorTransform);
			// 		}
					
			// 		for (i in 0...4) {
						
			// 			__bufferData[__bufferStride * i + 6] = colorTransform.redMultiplier;
			// 			__bufferData[__bufferStride * i + 11] = colorTransform.greenMultiplier;
			// 			__bufferData[__bufferStride * i + 16] = colorTransform.blueMultiplier;
			// 			__bufferData[__bufferStride * i + 21] = colorTransform.alphaMultiplier;
			// 			__bufferData[__bufferStride * i + 22] = colorTransform.redOffset / 255;
			// 			__bufferData[__bufferStride * i + 23] = colorTransform.greenOffset / 255;
			// 			__bufferData[__bufferStride * i + 24] = colorTransform.blueOffset / 255;
			// 			__bufferData[__bufferStride * i + 25] = colorTransform.alphaOffset / 255;
						
			// 		}
					
			// 	} else {
					
			// 		for (i in 0...4) {
						
			// 			__bufferData[__bufferStride * i + 6] = 1;
			// 			__bufferData[__bufferStride * i + 11] = 1;
			// 			__bufferData[__bufferStride * i + 16] = 1;
			// 			__bufferData[__bufferStride * i + 21] = 1;
			// 			__bufferData[__bufferStride * i + 22] = 0;
			// 			__bufferData[__bufferStride * i + 23] = 0;
			// 			__bufferData[__bufferStride * i + 24] = 0;
			// 			__bufferData[__bufferStride * i + 25] = 0;
						
			// 		}
					
			// 	}
				
			// }
			
			context.__bindBuffer (gl.ARRAY_BUFFER, __buffer);
			
			// if (dirty) {
			
			// 	gl.bufferData (gl.ARRAY_BUFFER, __bufferData.byteLength, __bufferData, gl.STATIC_DRAW);
			
			// }
			
		}
		
		return __buffer;
		
	}
	
	
	/**
	 * Determines a rectangular region that either fully encloses all pixels of a
	 * specified color within the bitmap image(if the `findColor`
	 * parameter is set to `true`) or fully encloses all pixels that
	 * do not include the specified color(if the `findColor`
	 * parameter is set to `false`).
	 *
	 * For example, if you have a source image and you want to determine the
	 * rectangle of the image that contains a nonzero alpha channel, pass
	 * `{mask: 0xFF000000, color: 0x00000000}` as parameters. If the
	 * `findColor` parameter is set to `true`, the entire
	 * image is searched for the bounds of pixels for which `(value & mask)
	 * == color`(where `value` is the color value of the
	 * pixel). If the `findColor` parameter is set to
	 * `false`, the entire image is searched for the bounds of pixels
	 * for which `(value & mask) != color`(where `value`
	 * is the color value of the pixel). To determine white space around an
	 * image, pass `{mask: 0xFFFFFFFF, color: 0xFFFFFFFF}` to find the
	 * bounds of nonwhite pixels.
	 * 
	 * @param mask      A hexadecimal value, specifying the bits of the ARGB
	 *                  color to consider. The color value is combined with this
	 *                  hexadecimal value, by using the `&`(bitwise
	 *                  AND) operator.
	 * @param color     A hexadecimal value, specifying the ARGB color to match
	 *                 (if `findColor` is set to `true`)
	 *                  or _not_ to match(if `findColor` is set
	 *                  to `false`).
	 * @param findColor If the value is set to `true`, returns the
	 *                  bounds of a color value in an image. If the value is set
	 *                  to `false`, returns the bounds of where this
	 *                  color doesn't exist in an image.
	 * @return The region of the image that is the specified color.
	 */
	public function getColorBoundsRect (mask:Int, color:Int, findColor:Bool = true):Rectangle {
		
		if (!readable) return new Rectangle (0, 0, width, height);
		
		if (!transparent || ((mask >> 24) & 0xFF) > 0) {
			
			var color = (color:ARGB);
			if (color.a == 0) color = 0;
			
		}
		
		var rect = image.getColorBoundsRect (mask, color, findColor, ARGB32);
		return new Rectangle (rect.x, rect.y, rect.width, rect.height);
		
	}
	
	
	/**
	 * Returns an integer that represents an RGB pixel value from a BitmapData
	 * object at a specific point(_x_, _y_). The
	 * `getPixel()` method returns an unmultiplied pixel value. No
	 * alpha information is returned.
	 *
	 * All pixels in a BitmapData object are stored as premultiplied color
	 * values. A premultiplied image pixel has the red, green, and blue color
	 * channel values already multiplied by the alpha data. For example, if the
	 * alpha value is 0, the values for the RGB channels are also 0, independent
	 * of their unmultiplied values. This loss of data can cause some problems
	 * when you perform operations. All BitmapData methods take and return
	 * unmultiplied values. The internal pixel representation is converted from
	 * premultiplied to unmultiplied before it is returned as a value. During a
	 * set operation, the pixel value is premultiplied before the raw image pixel
	 * is set.
	 * 
	 * @param x The _x_ position of the pixel.
	 * @param y The _y_ position of the pixel.
	 * @return A number that represents an RGB pixel value. If the(_x_,
	 *         _y_) coordinates are outside the bounds of the image, the
	 *         method returns 0.
	 */
	public function getPixel (x:Int, y:Int):Int {
		
		if (!readable) return 0;
		return image.getPixel (x, y, ARGB32);
		
	}
	
	
	/**
	 * Returns an ARGB color value that contains alpha channel data and RGB data.
	 * This method is similar to the `getPixel()` method, which
	 * returns an RGB color without alpha channel data.
	 *
	 * All pixels in a BitmapData object are stored as premultiplied color
	 * values. A premultiplied image pixel has the red, green, and blue color
	 * channel values already multiplied by the alpha data. For example, if the
	 * alpha value is 0, the values for the RGB channels are also 0, independent
	 * of their unmultiplied values. This loss of data can cause some problems
	 * when you perform operations. All BitmapData methods take and return
	 * unmultiplied values. The internal pixel representation is converted from
	 * premultiplied to unmultiplied before it is returned as a value. During a
	 * set operation, the pixel value is premultiplied before the raw image pixel
	 * is set.
	 * 
	 * @param x The _x_ position of the pixel.
	 * @param y The _y_ position of the pixel.
	 * @return A number representing an ARGB pixel value. If the(_x_,
	 *         _y_) coordinates are outside the bounds of the image, 0 is
	 *         returned.
	 */
	public function getPixel32 (x:Int, y:Int):Int {
		
		if (!readable) return 0;
		return image.getPixel32 (x, y, ARGB32);
		
	}
	
	
	/**
	 * Generates a byte array from a rectangular region of pixel data. Writes an
	 * unsigned integer(a 32-bit unmultiplied pixel value) for each pixel into
	 * the byte array.
	 * 
	 * @param rect A rectangular area in the current BitmapData object.
	 * @return A ByteArray representing the pixels in the given Rectangle.
	 * @throws TypeError The rect is null.
	 */
	public function getPixels (rect:Rectangle):ByteArray {
		
		if (!readable) return null;
		if (rect == null) rect = this.rect;
		var byteArray = ByteArray.fromBytes (image.getPixels (rect.__toLimeRectangle (), ARGB32));
		// TODO: System endian order
		byteArray.endian = BIG_ENDIAN;
		return byteArray;
		
	}
	
	
	@:dox(hide) public function getSurface ():CairoImageSurface {
		
		if (!readable) return null;
		
		if (__surface == null) {
			
			__surface = CairoImageSurface.fromImage (image);
			
		}
		
		return __surface;
		
	}
	
	
	@:dox(hide) public function getTexture (context:Context3D):GLTexture {
		
		if (!__isValid) return null;
		
		var gl = context.__gl;
		
		if (__texture == null || __textureContext != context.__context) {
			
			__textureContext = context.__context;
			__texture = gl.createTexture ();
			
			context.__bindTexture (gl.TEXTURE_2D, __texture);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
			gl.texParameteri (gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
			__textureVersion = -1;
			
		}
		
		#if (js && html5)
		ImageCanvasUtil.sync (image, false);
		#end
		
		if (image != null && image.version > __textureVersion) {
			
			var internalFormat, format;
			
			if (__surface != null) {
				
				__surface.flush ();
				
			}
			
			if (image.buffer.bitsPerPixel == 1) {
				
				internalFormat = gl.ALPHA;
				format = gl.ALPHA;
				
			} else {
				
				if (__supportsBGRA == null) {
					
					__textureInternalFormat = gl.RGBA;
					
					var bgraExtension = null;
					#if (!js || !html5)
					bgraExtension = gl.getExtension ("EXT_bgra");
					if (bgraExtension == null)
						bgraExtension = gl.getExtension ("EXT_texture_format_BGRA8888");
					if (bgraExtension == null)
						bgraExtension = gl.getExtension ("APPLE_texture_format_BGRA8888");
					#end
					
					if (bgraExtension != null) {
						
						__supportsBGRA = true;
						__textureFormat = bgraExtension.BGRA_EXT;
						
						#if (!ios && !tvos)
						if (context.__context.type == #if (lime >= "7.0.0") OPENGLES #else GLES #end) {
							
							__textureInternalFormat = bgraExtension.BGRA_EXT;
							
						}
						#end
						
					} else {
						
						__supportsBGRA = false;
						__textureFormat = gl.RGBA;
						
					}
					
				}
				
				internalFormat = __textureInternalFormat;
				format = __textureFormat;
				
			}
			
			context.__bindTexture (gl.TEXTURE_2D, __texture);
			
			var textureImage = image;
			
			#if (js && html5)
			
			if (textureImage.type != DATA && !textureImage.premultiplied) {
				
				gl.pixelStorei (gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
				
			} else if (!textureImage.premultiplied && textureImage.transparent) {
				
				gl.pixelStorei (gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
				//gl.pixelStorei (gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
				//textureImage = textureImage.clone ();
				//textureImage.premultiplied = true;
				
			}
			
			// TODO: Some way to support BGRA on WebGL?
			
			var cloned:Bool = false;
			
			if (!__supportsBGRA && textureImage.format != RGBA32) {
				
				textureImage = textureImage.clone ();
				cloned = true;
				textureImage.format = RGBA32;
				//textureImage.buffer.premultiplied = true;
				
			}
			
			#if openfl_power_of_two
			if (!cloned) {
				
				textureImage = textureImage.clone ();
				
			}
			
			textureImage.powerOfTwo = true;
			#end
			
			if (textureImage.type == DATA) {
				
				gl.texImage2D (gl.TEXTURE_2D, 0, internalFormat, textureImage.buffer.width, textureImage.buffer.height, 0, format, gl.UNSIGNED_BYTE, textureImage.data);
				
			} else {
				
				gl.texImage2D (gl.TEXTURE_2D, 0, internalFormat, format, gl.UNSIGNED_BYTE, textureImage.src);
				
			}
			
			#else
			
			if (#if openfl_power_of_two !textureImage.powerOfTwo || #end (!textureImage.premultiplied && textureImage.transparent)) {
				
				textureImage = textureImage.clone ();
				textureImage.premultiplied = true;
				#if openfl_power_of_two
				textureImage.powerOfTwo = true;
				#end
				
			}
			
			gl.texImage2D (gl.TEXTURE_2D, 0, internalFormat, textureImage.buffer.width, textureImage.buffer.height, 0, format, gl.UNSIGNED_BYTE, textureImage.data);
			
			#end
			
			context.__bindTexture (gl.TEXTURE_2D, null);
			__textureVersion = image.version;
			
			__textureWidth = textureImage.buffer.width;
			__textureHeight = textureImage.buffer.height;
			
		}
		
		if (!readable && image != null) {
			
			__surface = null;
			image = null;
			
		}
		
		return __texture;
		
	}
	
	
	/**
	 * Generates a vector array from a rectangular region of pixel data. Returns
	 * a Vector object of unsigned integers(a 32-bit unmultiplied pixel value)
	 * for the specified rectangle.
	 * 
	 * @param rect A rectangular area in the current BitmapData object.
	 * @return A Vector representing the given Rectangle.
	 * @throws TypeError The rect is null.
	 */
	public function getVector (rect:Rectangle) {
		
		var pixels = getPixels (rect);
		var length = Std.int (pixels.length / 4);
		var result = new Vector<UInt> (length, true);
		
		for (i in 0...length) {
			
			result[i] = pixels.readUnsignedInt ();
			
		}
		
		return result;
		
	}
	
	
	public function histogram (hRect:Rectangle = null) {
		
		var rect = hRect != null ? hRect : new Rectangle (0, 0, width, height);
		var pixels = getPixels (rect);
		var result = [for (i in 0...4) [for (j in 0...256) 0]];
		
		for (i in 0...pixels.length) {
			
			++result[i % 4][pixels.readUnsignedByte ()];
			
		}
		
		return result;
		
	}
	
	
	public function hitTest (firstPoint:Point, firstAlphaThreshold:Int, secondObject:Object, secondBitmapDataPoint:Point = null, secondAlphaThreshold:Int = 1):Bool {
		
		if (!readable) return false;
		
		// #if !openfljs
		if (Std.is (secondObject, Bitmap)) {
			
			secondObject = cast (secondObject, Bitmap).__bitmapData;
			
		}
		// #end
		
		if (Std.is (secondObject, Point)) {
			
			var secondPoint:Point = cast secondObject;
			
			var x = Std.int (secondPoint.x - firstPoint.x);
			var y = Std.int (secondPoint.y - firstPoint.y);
			
			if (rect.contains (x, y)) {
				
				var pixel = getPixel32 (x, y);
				
				if ((pixel >> 24) & 0xFF > firstAlphaThreshold) {
					
					return true;
					
				}
				
			}
			
		} else if (Std.is (secondObject, BitmapData)) {
			
			var secondBitmapData:BitmapData = cast secondObject;
			var x, y;
			
			if (secondBitmapDataPoint == null) {
				
				x = 0;
				y = 0;
				
			} else {
				
				x = Math.round (secondBitmapDataPoint.x - firstPoint.x);
				y = Math.round (secondBitmapDataPoint.y - firstPoint.y);
				
			}
			
			var hitRect = Rectangle.__pool.get ();
			hitRect.setTo (x, y, secondBitmapData.width, secondBitmapData.height);
			
			if (rect.intersects (hitRect)) {
				
				if (x < 0) {
					
					hitRect.x = 0;
					hitRect.width = Math.min (secondBitmapData.width + x, width);
					
				} else {
					
					hitRect.width = Math.min (secondBitmapData.width, width - x);
					
				}
				
				if (y < 0) {
					
					hitRect.y = 0;
					hitRect.height = Math.min (secondBitmapData.height + y, height);
					
				} else {
					
					hitRect.height = Math.min (secondBitmapData.height, height - y);
					
				}
				
				var pixels = getPixels (hitRect);
				
				hitRect.x = (x < 0) ? -x : 0;
				hitRect.y = (y < 0) ? -y : 0;
				
				var testPixels = secondBitmapData.getPixels (hitRect);
				
				var length = Std.int (hitRect.width * hitRect.height);
				var pixel, testPixel;
				
				for (i in 0...length) {
					
					pixel = pixels.readUnsignedInt ();
					testPixel = testPixels.readUnsignedInt ();
					
					if ((pixel >> 24) & 0xFF > firstAlphaThreshold && (testPixel >> 24) & 0xFF > secondAlphaThreshold) {
						
						Rectangle.__pool.release (hitRect);
						return true;
						
					}
					
				}
				
			}
			
			Rectangle.__pool.release (hitRect);
			
		} else if (Std.is (secondObject, Rectangle)) {
			
			var secondRectangle = Rectangle.__pool.get ();
			secondRectangle.copyFrom (cast secondObject);
			secondRectangle.offset (-firstPoint.x, -firstPoint.y);
			secondRectangle.__contract (0, 0, width, height);
			
			if (secondRectangle.width > 0 && secondRectangle.height > 0) {
				
				var pixels = getPixels (secondRectangle);
				var length = Std.int (pixels.length / 4);
				var pixel;
				
				for (i in 0...length) {
					
					pixel = pixels.readUnsignedInt ();
					
					if ((pixel >> 24) & 0xFF > firstAlphaThreshold) {
						
						Rectangle.__pool.release (secondRectangle);
						return true;
						
					}
					
				}
				
			}
			
			Rectangle.__pool.release (secondRectangle);
			
		}
		
		return false;
		
	}
	
	
	public static function loadFromBase64 (base64:String, type:String):Future<BitmapData> {
		
		return Image.loadFromBase64 (base64, type).then (function (image) {
			
			return Future.withValue (BitmapData.fromImage (image));
			
		});
		
	}
	
	
	public static function loadFromBytes (bytes:ByteArray, rawAlpha:ByteArray = null):Future<BitmapData> {
		
		return Image.loadFromBytes (bytes).then (function (image) {
			
			var bitmapData = BitmapData.fromImage (image);
			
			if (rawAlpha != null) {
				
				bitmapData.__applyAlpha (rawAlpha);
				
			}
			
			return Future.withValue (bitmapData);
			
		});
		
	}
	
	
	public static function loadFromFile (path:String):Future<BitmapData> {
		
		return Image.loadFromFile (path).then (function (image) {
			
			return Future.withValue (BitmapData.fromImage (image));
			
		});
		
	}
	
	
	/**
	 * Locks an image so that any objects that reference the BitmapData object,
	 * such as Bitmap objects, are not updated when this BitmapData object
	 * changes. To improve performance, use this method along with the
	 * `unlock()` method before and after numerous calls to the
	 * `setPixel()` or `setPixel32()` method.
	 * 
	 */
	public function lock ():Void {
		
		
		
	}
	
	
	public function merge (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, redMultiplier:UInt, greenMultiplier:UInt, blueMultiplier:UInt, alphaMultiplier:UInt):Void {
		
		if (!readable || sourceBitmapData == null || !sourceBitmapData.readable || sourceRect == null || destPoint == null) return;
		image.merge (sourceBitmapData.image, sourceRect.__toLimeRectangle (), destPoint.__toLimeVector2 (), redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier);
		
	}
	
	
	/**
	 * Fills an image with pixels representing random noise.
	 * 
	 * @param randomSeed     The random seed number to use. If you keep all other
	 *                       parameters the same, you can generate different
	 *                       pseudo-random results by varying the random seed
	 *                       value. The noise function is a mapping function, not
	 *                       a true random-number generation function, so it
	 *                       creates the same results each time from the same
	 *                       random seed.
	 * @param low            The lowest value to generate for each channel(0 to
	 *                       255).
	 * @param high           The highest value to generate for each channel(0 to
	 *                       255).
	 * @param channelOptions A number that can be a combination of any of the
	 *                       four color channel values
	 *                      (`BitmapDataChannel.RED`,
	 *                       `BitmapDataChannel.BLUE`,
	 *                       `BitmapDataChannel.GREEN`, and
	 *                       `BitmapDataChannel.ALPHA`). You can use
	 *                       the logical OR operator(`|`) to combine
	 *                       channel values.
	 * @param grayScale      A Boolean value. If the value is `true`,
	 *                       a grayscale image is created by setting all of the
	 *                       color channels to the same value. The alpha channel
	 *                       selection is not affected by setting this parameter
	 *                       to `true`.
	 */
	public function noise (randomSeed:Int, low:Int = 0, high:Int = 255, channelOptions:Int = 7, grayScale:Bool = false):Void {
		
		if (!readable) return;
		
		//Seeded Random Number Generator
		var rand:Void->Int = {
			function func():Int 
			{	
				randomSeed = randomSeed * 1103515245 + 12345; 
				return Std.int(Math.abs(randomSeed / 65536)) % 32768; 
			}
		};
		rand();
		
		//Range of values to value to.
		var range:Int = high - low;
		var data:ByteArray = new ByteArray();
		
		var redChannel:Bool = ((channelOptions & ( 1 << 0 )) >> 0) == 1;
		var greenChannel:Bool = ((channelOptions & ( 1 << 1 )) >> 1) == 1;
		var blueChannel:Bool = ((channelOptions & ( 1 << 2 )) >> 2) == 1;
		var alphaChannel:Bool = ((channelOptions & ( 1 << 3 )) >> 3) == 1;
		
		for (y in 0...height)
		{
			for (x in 0...width)
			{
				//Default channel colours if all channel options are false.
				var red:Int = 0;
				var blue:Int = 0;
				var green:Int = 0;
				var alpha:Int = 255;
				
				if (grayScale)
				{
					red = green = blue = low + (rand() % range);
					alpha = 255;
				}
				else
				{
					if (redChannel) red = low + (rand() % range);
					if (greenChannel) green = low + (rand() % range);
					if (blueChannel) blue = low + (rand() % range);
					if (alphaChannel) alpha = low + (rand() % range);
				}
				
				var rgb:Int = alpha;
				rgb = (rgb << 8) + red;
				rgb = (rgb << 8) + green;
				rgb = (rgb << 8) + blue;
				
				setPixel32(x, y, rgb);
			}
		}
		
	}
	
	
	public function paletteMap (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, redArray:Array<Int> = null, greenArray:Array<Int> = null, blueArray:Array<Int> = null, alphaArray:Array<Int> = null):Void {
		
		var sw:Int = Std.int (sourceRect.width);
		var sh:Int = Std.int (sourceRect.height);
		
		var pixels = sourceBitmapData.getPixels (sourceRect);
		
		var pixelValue:Int, r:Int, g:Int, b:Int, a:Int, color:Int;
		
		for (i in 0...(sh * sw)) {
			
			pixelValue = pixels.readUnsignedInt();
			
			a = (alphaArray == null) ? pixelValue & 0xFF000000 : alphaArray[(pixelValue >> 24) & 0xFF];
			r = (redArray == null) ? pixelValue & 0x00FF0000 : redArray[(pixelValue >> 16) & 0xFF];
			g = (greenArray == null) ? pixelValue & 0x0000FF00 : greenArray[(pixelValue >> 8) & 0xFF];
			b = (blueArray == null) ? pixelValue & 0x000000FF : blueArray[(pixelValue) & 0xFF];
			
			color = a + r + g + b;
			
			pixels.position = i * 4;
			pixels.writeUnsignedInt(color);
			
		}
		
		pixels.position = 0;
		var destRect = Rectangle.__pool.get ();
		destRect.setTo (destPoint.x, destPoint.y, sw, sh);
		setPixels (destRect, pixels);
		Rectangle.__pool.release (destRect);
		
	}
	
	
	/**
	 * Generates a Perlin noise image.
	 *
	 * The Perlin noise generation algorithm interpolates and combines
	 * individual random noise functions(called octaves) into a single function
	 * that generates more natural-seeming random noise. Like musical octaves,
	 * each octave function is twice the frequency of the one before it. Perlin
	 * noise has been described as a "fractal sum of noise" because it combines
	 * multiple sets of noise data with different levels of detail.
	 *
	 * You can use Perlin noise functions to simulate natural phenomena and
	 * landscapes, such as wood grain, clouds, and mountain ranges. In most
	 * cases, the output of a Perlin noise function is not displayed directly but
	 * is used to enhance other images and give them pseudo-random
	 * variations.
	 *
	 * Simple digital random noise functions often produce images with harsh,
	 * contrasting points. This kind of harsh contrast is not often found in
	 * nature. The Perlin noise algorithm blends multiple noise functions that
	 * operate at different levels of detail. This algorithm results in smaller
	 * variations among neighboring pixel values.
	 * 
	 * @param baseX          Frequency to use in the _x_ direction. For
	 *                       example, to generate a noise that is sized for a 64
	 *                       x 128 image, pass 64 for the `baseX`
	 *                       value.
	 * @param baseY          Frequency to use in the _y_ direction. For
	 *                       example, to generate a noise that is sized for a 64
	 *                       x 128 image, pass 128 for the `baseY`
	 *                       value.
	 * @param numOctaves     Number of octaves or individual noise functions to
	 *                       combine to create this noise. Larger numbers of
	 *                       octaves create images with greater detail. Larger
	 *                       numbers of octaves also require more processing
	 *                       time.
	 * @param randomSeed     The random seed number to use. If you keep all other
	 *                       parameters the same, you can generate different
	 *                       pseudo-random results by varying the random seed
	 *                       value. The Perlin noise function is a mapping
	 *                       function, not a true random-number generation
	 *                       function, so it creates the same results each time
	 *                       from the same random seed.
	 * @param stitch         A Boolean value. If the value is `true`,
	 *                       the method attempts to smooth the transition edges
	 *                       of the image to create seamless textures for tiling
	 *                       as a bitmap fill.
	 * @param fractalNoise   A Boolean value. If the value is `true`,
	 *                       the method generates fractal noise; otherwise, it
	 *                       generates turbulence. An image with turbulence has
	 *                       visible discontinuities in the gradient that can
	 *                       make it better approximate sharper visual effects
	 *                       like flames and ocean waves.
	 * @param channelOptions A number that can be a combination of any of the
	 *                       four color channel values
	 *                      (`BitmapDataChannel.RED`,
	 *                       `BitmapDataChannel.BLUE`,
	 *                       `BitmapDataChannel.GREEN`, and
	 *                       `BitmapDataChannel.ALPHA`). You can use
	 *                       the logical OR operator(`|`) to combine
	 *                       channel values.
	 * @param grayScale      A Boolean value. If the value is `true`,
	 *                       a grayscale image is created by setting each of the
	 *                       red, green, and blue color channels to identical
	 *                       values. The alpha channel value is not affected if
	 *                       this value is set to `true`.
	 */
	public function perlinNoise (baseX:Float, baseY:Float, numOctaves:UInt, randomSeed:Int, stitch:Bool, fractalNoise:Bool, channelOptions:UInt = 7, grayScale:Bool = false, offsets:Array<Point> = null):Void {
		
		if (!readable) return;
		var noise = new PerlinNoise (randomSeed, numOctaves, 0.01);
		noise.fill (this, baseX, baseY, 0);
		
	}
	
	
	// @:noCompletion @:dox(hide) public function pixelDissolve (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, randomSeed:Int = 0, numPixels:Int = 0, fillColor:UInt = 0):Int;
	
	
	/**
	 * Scrolls an image by a certain(_x_, _y_) pixel amount. Edge
	 * regions outside the scrolling area are left unchanged.
	 * 
	 * @param x The amount by which to scroll horizontally.
	 * @param y The amount by which to scroll vertically.
	 */
	public function scroll (x:Int, y:Int):Void {
		
		if (!readable) return;
		image.scroll (x, y);
		
	}
	
	
	/**
	 * Sets a single pixel of a BitmapData object. The current alpha channel
	 * value of the image pixel is preserved during this operation. The value of
	 * the RGB color parameter is treated as an unmultiplied color value.
	 *
	 * **Note:** To increase performance, when you use the
	 * `setPixel()` or `setPixel32()` method repeatedly,
	 * call the `lock()` method before you call the
	 * `setPixel()` or `setPixel32()` method, and then call
	 * the `unlock()` method when you have made all pixel changes.
	 * This process prevents objects that reference this BitmapData instance from
	 * updating until you finish making the pixel changes.
	 * 
	 * @param x     The _x_ position of the pixel whose value changes.
	 * @param y     The _y_ position of the pixel whose value changes.
	 * @param color The resulting RGB color for the pixel.
	 */
	public function setPixel (x:Int, y:Int, color:Int):Void {
		
		if (!readable) return;
		image.setPixel (x, y, color, ARGB32);
		
	}
	
	
	/**
	 * Sets the color and alpha transparency values of a single pixel of a
	 * BitmapData object. This method is similar to the `setPixel()`
	 * method; the main difference is that the `setPixel32()` method
	 * takes an ARGB color value that contains alpha channel information.
	 *
	 * All pixels in a BitmapData object are stored as premultiplied color
	 * values. A premultiplied image pixel has the red, green, and blue color
	 * channel values already multiplied by the alpha data. For example, if the
	 * alpha value is 0, the values for the RGB channels are also 0, independent
	 * of their unmultiplied values. This loss of data can cause some problems
	 * when you perform operations. All BitmapData methods take and return
	 * unmultiplied values. The internal pixel representation is converted from
	 * premultiplied to unmultiplied before it is returned as a value. During a
	 * set operation, the pixel value is premultiplied before the raw image pixel
	 * is set.
	 *
	 * **Note:** To increase performance, when you use the
	 * `setPixel()` or `setPixel32()` method repeatedly,
	 * call the `lock()` method before you call the
	 * `setPixel()` or `setPixel32()` method, and then call
	 * the `unlock()` method when you have made all pixel changes.
	 * This process prevents objects that reference this BitmapData instance from
	 * updating until you finish making the pixel changes.
	 * 
	 * @param x     The _x_ position of the pixel whose value changes.
	 * @param y     The _y_ position of the pixel whose value changes.
	 * @param color The resulting ARGB color for the pixel. If the bitmap is
	 *              opaque(not transparent), the alpha transparency portion of
	 *              this color value is ignored.
	 */
	public function setPixel32 (x:Int, y:Int, color:Int):Void {
		
		if (!readable) return;
		image.setPixel32 (x, y, color, ARGB32);
		
	}
	
	
	/**
	 * Converts a byte array into a rectangular region of pixel data. For each
	 * pixel, the `ByteArray.readUnsignedInt()` method is called and
	 * the return value is written into the pixel. If the byte array ends before
	 * the full rectangle is written, the function returns. The data in the byte
	 * array is expected to be 32-bit ARGB pixel values. No seeking is performed
	 * on the byte array before or after the pixels are read.
	 * 
	 * @param rect           Specifies the rectangular region of the BitmapData
	 *                       object.
	 * @param inputByteArray A ByteArray object that consists of 32-bit
	 *                       unmultiplied pixel values to be used in the
	 *                       rectangular region.
	 * @throws EOFError  The `inputByteArray` object does not include
	 *                   enough data to fill the area of the `rect`
	 *                   rectangle. The method fills as many pixels as possible
	 *                   before throwing the exception.
	 * @throws TypeError The rect or inputByteArray are null.
	 */
	public function setPixels (rect:Rectangle, byteArray:ByteArray):Void {
		
		if (!readable || rect == null) return;
		
		var length = (rect.width * rect.height * 4);
		if (byteArray.bytesAvailable < length) throw new Error ("End of file was encountered.", 2030);
		
		image.setPixels (rect.__toLimeRectangle (), byteArray, ARGB32, byteArray.endian);
		
	}
	
	
	/**
	 * Converts a Vector into a rectangular region of pixel data. For each pixel,
	 * a Vector element is read and written into the BitmapData pixel. The data
	 * in the Vector is expected to be 32-bit ARGB pixel values.
	 * 
	 * @param rect Specifies the rectangular region of the BitmapData object.
	 * @throws RangeError The vector array is not large enough to read all the
	 *                    pixel data.
	 */
	public function setVector (rect:Rectangle, inputVector:Vector<UInt>) {
		
		var byteArray = new ByteArray ();
		byteArray.length = inputVector.length * 4;
		
		for (color in inputVector) {
			
			byteArray.writeUnsignedInt (color);
			
		}
		
		byteArray.position = 0;
		setPixels (rect, byteArray);
		
	}
	
	
	/**
	 * Tests pixel values in an image against a specified threshold and sets
	 * pixels that pass the test to new color values. Using the
	 * `threshold()` method, you can isolate and replace color ranges
	 * in an image and perform other logical operations on image pixels.
	 *
	 * The `threshold()` method's test logic is as follows:
	 *
	 *  1. If `((pixelValue & mask) operation(threshold & mask))`,
	 * then set the pixel to `color`;
	 *  2. Otherwise, if `copySource == true`, then set the pixel to
	 * corresponding pixel value from `sourceBitmap`.
	 *
	 * The `operation` parameter specifies the comparison operator
	 * to use for the threshold test. For example, by using "==" as the
	 * `operation` parameter, you can isolate a specific color value
	 * in an image. Or by using `{operation: "<", mask: 0xFF000000,
	 * threshold: 0x7F000000, color: 0x00000000}`, you can set all
	 * destination pixels to be fully transparent when the source image pixel's
	 * alpha is less than 0x7F. You can use this technique for animated
	 * transitions and other effects.
	 * 
	 * @param sourceBitmapData The input bitmap image to use. The source image
	 *                         can be a different BitmapData object or it can
	 *                         refer to the current BitmapData instance.
	 * @param sourceRect       A rectangle that defines the area of the source
	 *                         image to use as input.
	 * @param destPoint        The point within the destination image(the
	 *                         current BitmapData instance) that corresponds to
	 *                         the upper-left corner of the source rectangle.
	 * @param operation        One of the following comparison operators, passed
	 *                         as a String: "<", "<=", ">", ">=", "==", "!="
	 * @param threshold        The value that each pixel is tested against to see
	 *                         if it meets or exceeds the threshhold.
	 * @param color            The color value that a pixel is set to if the
	 *                         threshold test succeeds. The default value is
	 *                         0x00000000.
	 * @param mask             The mask to use to isolate a color component.
	 * @param copySource       If the value is `true`, pixel values
	 *                         from the source image are copied to the
	 *                         destination when the threshold test fails. If the
	 *                         value is `false`, the source image is
	 *                         not copied when the threshold test fails.
	 * @return The number of pixels that were changed.
	 * @throws ArgumentError The operation string is not a valid operation
	 * @throws TypeError     The sourceBitmapData, sourceRect destPoint or
	 *                       operation are null.
	 */
	public function threshold (sourceBitmapData:BitmapData, sourceRect:Rectangle, destPoint:Point, operation:String, threshold:Int, color:Int = 0x00000000, mask:Int = 0xFFFFFFFF, copySource:Bool = false):Int {
		
		if (sourceBitmapData == null || sourceRect == null || destPoint == null || sourceRect.x > sourceBitmapData.width || sourceRect.y > sourceBitmapData.height || destPoint.x > width || destPoint.y > height) return 0;
		
		return image.threshold (sourceBitmapData.image, sourceRect.__toLimeRectangle (), destPoint.__toLimeVector2 (), operation, threshold, color, mask, copySource, ARGB32);
		
	}
	
	
	/**
	 * Unlocks an image so that any objects that reference the BitmapData object,
	 * such as Bitmap objects, are updated when this BitmapData object changes.
	 * To improve performance, use this method along with the `lock()`
	 * method before and after numerous calls to the `setPixel()` or
	 * `setPixel32()` method.
	 * 
	 * @param changeRect The area of the BitmapData object that has changed. If
	 *                   you do not specify a value for this parameter, the
	 *                   entire area of the BitmapData object is considered
	 *                   changed.
	 */
	public function unlock (changeRect:Rectangle = null):Void {
		
		
		
	}
	
	
	@:noCompletion private function __applyAlpha (alpha:ByteArray):Void {
		
		#if (js && html5)
		ImageCanvasUtil.convertToCanvas (image);
		ImageCanvasUtil.createImageData (image);
		#end
		
		var data = image.buffer.data;
		
		for (i in 0...alpha.length) {
			
			data[i * 4 + 3] = alpha.readUnsignedByte ();
			
		}
		
		image.version++;
		
	}
	
	
	@:noCompletion private function __drawCairo (source:IBitmapDrawable, renderer:CairoRenderer):Void {
		
		#if lime_cairo
		
		var cairo = renderer.cairo;
		
		if (source == this) {
			
			source = clone ();
			
		}
		
		if (!renderer.__allowSmoothing) cairo.antialias = NONE;
		
		renderer.__render (source);
		
		if (!renderer.__allowSmoothing) cairo.antialias = GOOD;
		
		cairo.target.flush ();
		
		image.dirty = true;
		image.version++;
		
		#end
		
	}
	
	
	@:noCompletion private function __drawCanvas (source:IBitmapDrawable, renderer:CanvasRenderer):Void {
		
		var buffer = image.buffer;
		
		if (!renderer.__allowSmoothing) renderer.applySmoothing (buffer.__srcContext, false);
		
		renderer.__render (source);
		
		if (!renderer.__allowSmoothing) renderer.applySmoothing (buffer.__srcContext, true);
		
		buffer.__srcContext.setTransform (1, 0, 0, 1, 0, 0);
		buffer.__srcImageData = null;
		buffer.data = null;
		
		image.dirty = true;
		image.version++;
		
	}
	
	
	@:noCompletion private function __drawGL (source:IBitmapDrawable, renderer:OpenGLRenderer):Void {
		
		var context = renderer.__context3D;
		var gl = context.__gl;
		
		context.__bindFramebuffer (gl.FRAMEBUFFER, __getFramebuffer (context, true));
		
		renderer.__render (source);
		
		context.__bindFramebuffer (gl.FRAMEBUFFER, null);
		
	}
	
	
	@:noCompletion private function __fillRect (rect:Rectangle, color:Int, allowFramebuffer:Bool):Void {
		
		if (rect == null) return;
		
		if (transparent && (color & 0xFF000000) == 0) {
			
			color = 0;
			
		}
		
		if (allowFramebuffer && __framebuffer != null && Lib.current.stage.__renderer.__type == OPENGL) {
			
			var renderer:OpenGLRenderer = cast Lib.current.stage.__renderer;
			var context = renderer.__context3D;
			var gl = context.__gl;
			var color:ARGB = (color:ARGB);
			var useScissor = !this.rect.equals (rect);
			
			context.__bindFramebuffer (gl.FRAMEBUFFER, __framebuffer);
			
			if (useScissor) {
				
				context.__enable (gl.SCISSOR_TEST);
				context.__scissor (Math.round (rect.x), Math.round (rect.y), Math.round (rect.width), Math.round (rect.height));
				
			}
			
			context.__clearColor (color.r / 0xFF, color.g / 0xFF, color.b / 0xFF, color.a / 0xFF);
			gl.clear (gl.COLOR_BUFFER_BIT);
			
			if (useScissor) {
				
				context.__disable (gl.SCISSOR_TEST);
				
			}
			
			context.__bindFramebuffer (gl.FRAMEBUFFER, null);
			
		} else if (readable) {
			
			image.fillRect (rect.__toLimeRectangle (), color, ARGB32);
			
		}
		
	}
	
	
	@:noCompletion private inline function __fromBase64 (base64:String, type:String):Void {
		
		var image = Image.fromBase64 (base64, type);
		__fromImage (image);
		
	}
	
	
	@:noCompletion private inline function __fromBytes (bytes:ByteArray, rawAlpha:ByteArray = null):Void {
		
		var image = Image.fromBytes (bytes);
		__fromImage (image);
		
		if (rawAlpha != null) {
			
			__applyAlpha (rawAlpha);
			
		}
		
	}
	
	
	@:noCompletion private function __fromFile (path:String):Void {
		
		var image = Image.fromFile (path);
		__fromImage (image);
		
	}
	
	
	@:noCompletion private function __fromImage (image:Image):Void {
		
		if (image != null && image.buffer != null) {
			
			this.image = image;
			
			width = image.width;
			height = image.height;
			rect = new Rectangle (0, 0, image.width, image.height);
			
			#if sys
			image.format = BGRA32;
			image.premultiplied = true;
			#end
			
			readable = true;
			__isValid = true;
			
		}
		
	}
	
	
	@:noCompletion private function __getBounds (rect:Rectangle, matrix:Matrix):Void {
		
		var bounds = Rectangle.__pool.get ();
		this.rect.__transform (bounds, matrix);
		rect.__expand (bounds.x, bounds.y, bounds.width, bounds.height);
		Rectangle.__pool.release (bounds);
		
	}
	
	
	@:noCompletion private function __getFramebuffer (context:Context3D, requireStencil:Bool):GLFramebuffer {
		
		if (__framebuffer == null || __framebufferContext != context.__context) {
			
			var gl = context.__gl;
			
			getTexture (context);
			
			__framebufferContext = context.__context;
			__framebuffer = gl.createFramebuffer ();
			
			context.__bindFramebuffer (gl.FRAMEBUFFER, __framebuffer);
			gl.framebufferTexture2D (gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, __texture, 0);
			
			if (gl.checkFramebufferStatus (gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
				
				trace (gl.getError ());
				
			}
			
		}
		
		if (requireStencil && __stencilBuffer == null) {
			
			var gl = context.__gl;
			
			__stencilBuffer = gl.createRenderbuffer ();
			context.__bindRenderbuffer (gl.RENDERBUFFER, __stencilBuffer);
			gl.renderbufferStorage (gl.RENDERBUFFER, gl.STENCIL_INDEX8, __textureWidth, __textureHeight);
			
			context.__bindFramebuffer (gl.FRAMEBUFFER, __framebuffer);
			gl.framebufferRenderbuffer (gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, __stencilBuffer);
			
			if (gl.checkFramebufferStatus (gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
				
				trace (gl.getError ());
				
			}
			
			context.__bindRenderbuffer (gl.RENDERBUFFER, null);
			
		}
		
		return __framebuffer;
		
	}
	
	
	@:noCompletion private inline function __loadFromBase64 (base64:String, type:String):Future<BitmapData> {
		
		return Image.loadFromBase64 (base64, type).then (function (image) {
			
			__fromImage (image);
			return Future.withValue (this);
			
		});
		
	}
	
	
	@:noCompletion private inline function __loadFromBytes (bytes:ByteArray, rawAlpha:ByteArray = null):Future<BitmapData> {
		
		return Image.loadFromBytes (bytes).then (function (image) {
			
			__fromImage (image);
			
			if (rawAlpha != null) {
				
				__applyAlpha (rawAlpha);
				
			}
			
			return Future.withValue (this);
			
		});
		
	}
	
	
	@:noCompletion private function __loadFromFile (path:String):Future<BitmapData> {
		
		return Image.loadFromFile (path).then (function (image) {
			
			__fromImage (image);
			return Future.withValue (this);
			
		});
		
	}
	
	
	@:noCompletion private function __renderCairo (renderer:CairoRenderer):Void {
		
		#if lime_cairo
		if (!readable) return;
		
		var cairo = renderer.cairo;
		
		renderer.applyMatrix (__renderTransform, cairo);
		
		var surface = getSurface ();
		
		if (surface != null) {
			
			var pattern = CairoPattern.createForSurface (surface);
			
			if (!renderer.__allowSmoothing || cairo.antialias == NONE) {
				
				pattern.filter = CairoFilter.NEAREST;
				
			} else {
				
				pattern.filter = CairoFilter.GOOD;
				
			}
			
			cairo.source = pattern;
			cairo.paint ();
			
		}
		#end
		
	}
	
	
	@:noCompletion private function __renderCairoMask (renderer:CairoRenderer):Void {
		
		
		
	}
	
	
	@:noCompletion private function __renderCanvas (renderer:CanvasRenderer):Void {
		
		#if (js && html5)
		if (!readable) return;
		
		if (image.type == DATA) {
			
			ImageCanvasUtil.convertToCanvas (image);
			
		}
		
		var context = renderer.context;
		context.globalAlpha = 1;
		
		renderer.setTransform (__renderTransform, context);
		
		context.drawImage (image.src, 0, 0, image.width, image.height);
		#end
		
	}
	
	
	@:noCompletion private function __renderCanvasMask (renderer:CanvasRenderer):Void {
		
		
		
	}
	
	
	@:noCompletion private function __renderDOM (renderer:DOMRenderer):Void {
		
		
		
	}
	
	
	@:noCompletion private function __renderGL (renderer:OpenGLRenderer):Void {
		
		var context = renderer.__context3D;
		var gl = context.__gl;
		
		renderer.__setBlendMode (NORMAL);
		
		var shader = renderer.__defaultDisplayShader;
		renderer.setShader (shader);
		renderer.applyBitmapData (this, renderer.__allowSmoothing && (renderer.__upscaled));
		renderer.applyMatrix (renderer.__getMatrix (__worldTransform));
		renderer.applyAlpha (__worldAlpha);
		renderer.applyColorTransform (__worldColorTransform);
		renderer.updateShader ();
		
		// alpha == 1, __worldColorTransform
		
		context.__bindBuffer (gl.ARRAY_BUFFER, getBuffer (context));
		if (shader.__position != null) gl.vertexAttribPointer (shader.__position.index, 3, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 0);
		if (shader.__textureCoord != null) gl.vertexAttribPointer (shader.__textureCoord.index, 2, gl.FLOAT, false, 5 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
		
		#if gl_stats
			GLStats.incrementDrawCall (DrawCallContext.STAGE);
		#end
		
		renderer.__clearShader ();
		
	}
	
	
	@:noCompletion private function __renderGLMask (renderer:OpenGLRenderer):Void {
		
		var context = renderer.__context3D;
		var gl = context.__gl;
		
		var shader = renderer.__maskShader;
		renderer.setShader (shader);
		renderer.applyBitmapData (this, renderer.__allowSmoothing && (renderer.__upscaled));
		renderer.applyMatrix (renderer.__getMatrix (__worldTransform));
		renderer.updateShader ();
		
		context.__bindBuffer (gl.ARRAY_BUFFER, getBuffer (context));
		gl.vertexAttribPointer (shader.__position.index, 3, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 0);
		gl.vertexAttribPointer (shader.__textureCoord.index, 2, gl.FLOAT, false, 6 * Float32Array.BYTES_PER_ELEMENT, 3 * Float32Array.BYTES_PER_ELEMENT);
		
		gl.drawArrays (gl.TRIANGLE_STRIP, 0, 4);
		
		#if gl_stats
			GLStats.incrementDrawCall (DrawCallContext.STAGE);
		#end
		
		renderer.__clearShader ();
		
	}
	
	
	function __resize (width:Int, height:Int) {
		
		this.width = width;
		this.height = height;
		this.rect.width = width;
		this.rect.height = height;
		
		__textureWidth = width;
		__textureHeight = height;
		
	}
	
	
	@:noCompletion private function __setUVRect (context:Context3D, x:Float, y:Float, width:Float, height:Float):Void {
		
		var buffer = getBuffer (context);
		
		if (buffer != null && (width != __uvRect.width || height != __uvRect.height || x != __uvRect.x || y != __uvRect.y)) {
			
			var gl = context.__gl;
			
			if (__uvRect == null) __uvRect = new Rectangle ();
			__uvRect.setTo (x, y, width, height);
			
			var uvX = __textureWidth > 0 ? x / __textureWidth : 0;
			var uvY = __textureHeight > 0 ? y / __textureHeight : 0;
			var uvWidth = __textureWidth > 0 ? width / __textureWidth : 0;
			var uvHeight = __textureHeight > 0 ? height / __textureHeight : 0;
			
			__bufferData[0] = width;
			__bufferData[1] = height;
			__bufferData[3] = uvX + uvWidth;
			__bufferData[4] = uvY + uvHeight;
			__bufferData[__bufferStride + 1] = height;
			__bufferData[__bufferStride + 3] = uvX;
			__bufferData[__bufferStride + 4] = uvY + uvHeight;
			__bufferData[__bufferStride * 2] = width;
			__bufferData[__bufferStride * 2 + 3] = uvX + uvWidth;
			__bufferData[__bufferStride * 2 + 4] = uvY;
			__bufferData[__bufferStride * 3 + 3] = uvX;
			__bufferData[__bufferStride * 3 + 4] = uvY;
			
			gl.bufferData (gl.ARRAY_BUFFER, __bufferData, gl.STATIC_DRAW);
			
			
		}
		
	}
	
	
	@:noCompletion private function __sync ():Void {
		
		#if (js && html5)
		ImageCanvasUtil.sync (image, false);
		#end
		
	}
	
	
	@:noCompletion private function __update (transformOnly:Bool, updateChildren:Bool):Void {
		
		__updateTransforms ();
		
	}
	
	
	@:noCompletion private function __updateTransforms (overrideTransform:Matrix = null):Void {
		
		if (overrideTransform == null) {
			
			__worldTransform.identity ();
			
		} else {
			
			__worldTransform.copyFrom (overrideTransform);
			
		}
		
		__renderTransform.copyFrom (__worldTransform);
		
	}
	
	
}


#else
typedef BitmapData = flash.display.BitmapData;
#end