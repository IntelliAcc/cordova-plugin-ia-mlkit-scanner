package com.intelliacc.MLKitBarcodeScanner.camera;

import android.content.Context;
import android.graphics.Canvas;
import android.util.AttributeSet;
import android.view.View;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.Vector;


public class MLKitGraphicOverlay<T extends MLKitGraphicOverlay.Graphic> extends View {
    
    private final Object _Lock = new Object();
    private int _PreviewWidth;
    private float _WidthScaleFactor = 1.0f;
    private int _PreviewHeight;
    private float _HeightScaleFactor = 1.0f;
    private int _Facing = 0;
    private Set<T> _Graphics = new HashSet<>();
    
    public MLKitGraphicOverlay(Context p_Context, AttributeSet p_AttributeSet) {
        super(p_Context, p_AttributeSet);
    }
    
    public void clear() {
        synchronized (_Lock) {
            _Graphics.clear();
        }
        postInvalidate();
    }
    
    public void add(T p_Graphic) {
        synchronized (_Lock) {
            _Graphics.add(p_Graphic);
        }
        postInvalidate();
    }
    
    public void remove(T p_Graphic) {
        synchronized (_Lock) {
            _Graphics.remove(p_Graphic);
        }
        postInvalidate();
    }
    
    public List<T> getGraphics() {
        synchronized (_Lock) {
            return new Vector(_Graphics);
        }
    }
    
    public float getWidthScaleFactor() {
        return _WidthScaleFactor;
    }
    
    public float getHeightScaleFactor() {
        return _HeightScaleFactor;
    }
    
    public void setCameraInfo(int p_PreviewWidth, int p_PreviewHeight, int p_Facing) {
        synchronized (_Lock) {
            _PreviewWidth = p_PreviewWidth;
            _PreviewHeight = p_PreviewHeight;
            _Facing = p_Facing;
        }
        postInvalidate();
    }
    
    @Override
    protected void onDraw(Canvas p_Canvas) {
        super.onDraw(p_Canvas);
        
        synchronized (_Lock) {
            if ((_PreviewWidth != 0) && (_PreviewHeight != 0)) {
                _WidthScaleFactor = (float)p_Canvas.getWidth() / (float)_PreviewWidth;
                _HeightScaleFactor = (float)p_Canvas.getHeight() / (float)_PreviewHeight;
            }
            
            for (Graphic graphic : _Graphics) {
                graphic.draw(p_Canvas);
            }
        }
    }
    
    public static abstract class Graphic {
        
        private MLKitGraphicOverlay _Overlay;
        
        public Graphic(MLKitGraphicOverlay overlay) {
            _Overlay = overlay;
        }
        
        public abstract void draw(Canvas canvas);
        
        public float scaleX(float horizontal) {
            return horizontal * _Overlay._WidthScaleFactor;
        }
        
        public float scaleY(float vertical) {
            return vertical * _Overlay._HeightScaleFactor;
        }
        
        public float translateX(float x) {
            if (_Overlay._Facing == 1) {
                return _Overlay.getWidth() - scaleX(x);
            } else {
                return scaleX(x);
            }
        }
        
        public float translateY(float y) {
            return scaleY(y);
        }
        
        public void postInvalidate() {
            _Overlay.postInvalidate();
        }
    }
}
