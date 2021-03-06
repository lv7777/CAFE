/+ ------------------------------------------------------------ +
 + Author : aoitofu <aoitofu@dr.com>                            +
 + This is part of CAFE ( https://github.com/aoitofu/CAFE ).    +
 + ------------------------------------------------------------ +
 + Please see /LICENSE.                                         +
 + ------------------------------------------------------------ +/
module cafe.gui.controls.PropertyEditor;
import cafe.project.ObjectPlacingInfo,
       cafe.project.Project,
       cafe.project.timeline.PlaceableObject,
       cafe.project.timeline.property.Property,
       cafe.project.timeline.property.PropertyList,
       cafe.project.timeline.effect.Effect,
       cafe.project.timeline.effect.EffectList,
       cafe.gui.Action,
       cafe.gui.controls.Chooser;
import std.algorithm,
       std.conv,
       std.string;
import dlangui,
       dlangui.widgets.metadata,
       dlangui.dialogs.dialog;

mixin( registerWidgets!PropertyEditor );

/+ プロパティを編集するウィジェット +/
class PropertyEditor : ScrollWidget
{
    private:
        Project pro;

        VerticalLayout main;

    public:
        @property project () { return pro; }
        @property project ( Project p )
        {
            pro = p;
            updateWidgets;
        }

        this ( string id = "" )
        {
            super( id );
            layoutWidth  = FILL_PARENT;
            layoutHeight = FILL_PARENT;
            styleId = "PROPERTY_EDITOR";
            hscrollbarMode = ScrollBarMode.Invisible;

            main = cast(VerticalLayout) addChild( new VerticalLayout );
            contentWidget = main;
        }

        void updateWidgets ()
        {
            if ( !project ) return;
            auto obj = project.selectingObject;

            main.removeAllChildren;
            if ( obj ) {
                auto f = project.componentList.selecting.timeline.frame.value.to!int -
                    obj.place.frame.start.value.to!int;
                f = min( obj.place.frame.length.value.to!int-1, max( 0, f ) );

                auto fat = new FrameAt( f.to!uint );
                main.addChild( new ObjectGroupPanelFrame( obj, fat, window ) );
                obj.effectList.effects.each!
                    ( x => main.addChild( new EffectGroupPanelFrame( x, obj.effectList, fat, window ) ) );
            }
            main.invalidate;
        }

        override void measure ( int w, int h )
        {
            main.minWidth = w - vscrollbar.width;
            super.measure( w, h );
        }
}

/+ 一つのグループの外枠 +/
private abstract class GroupPanelFrame : VerticalLayout
{
    enum HeaderLayout = q{
        HorizontalLayout {
            id:main;
            layoutWidth:FILL_PARENT;
            styleId:PROPERTY_EDITOR_GROUP_HEADER;
            HSpacer {}
            TextWidget { id:header; fontSize:16; alignment:VCenter }
            HSpacer {}
        }
    };

    class CustomButton : ImageButton
    {
        this ( string icon )
        {
            super( "", icon );
            alignment = Align.VCenter;
            styleId = "PROPERTY_EDITOR_HEADER_BUTTON";
        }
    }

    protected:
        PropertyPanel panel;

    public:
        this ( PropertyList l, string title, FrameAt f )
        {
            super();
            margins = Rect( 5, 5, 5, 5 );
            padding = Rect( 5, 5, 5, 5 );

            addChild( parseML(HeaderLayout) );
            panel = cast(PropertyPanel)addChild( new PropertyPanel( l, f ) );

            childById( "header" ).text = title.to!dstring;
        }
}

/+ オブジェクト用外枠 +/
private class ObjectGroupPanelFrame : GroupPanelFrame
{
    public:
        this ( PlaceableObject o, FrameAt f, Window w )
        {
            super( o.propertyList, o.name, f );
            childById("main").addChild( new CustomButton( "new" ) )
                .click = delegate ( Widget w )
                {
                    new EffectChooser( o , window ).show;
                    return true;
                };
        }
}

/+ エフェクト用外枠 +/
private class EffectGroupPanelFrame : GroupPanelFrame
{
    public:
        // イベント送信用にウィンドウも渡す
        this ( Effect e, EffectList el, FrameAt f, Window w )
        {
            super( e.propertyList, e.name, f );

            void update ( bool edit = true )
            {
                if ( edit )
                    w.mainWidget.handleAction( Action_PreviewRefresh );
                w.mainWidget.handleAction( Action_ObjectRefresh );
                w.mainWidget.handleAction( Action_TimelineRefresh );
            }
            auto main = childById( "main" );

            main.addChild( new CustomButton( "up" ) )
                .click = delegate ( Widget w )
                {
                    el.up( e ); update;
                    return true;
                };
            main.addChild( new CustomButton( "down" ) )
                .click = delegate ( Widget w )
                {
                    el.down( e ); update;
                    return true;
                };
            main.addChild( new CustomButton( e.enable ? "visible" : "invisible" ) )
                .click = delegate ( Widget w )
                {
                    e.enable = !e.enable;
                    (cast(ImageWidget)w).drawableId =
                        e.enable ? "visible" : "invisible";
                    update;
                    return true;
                };
            main.addChild( new CustomButton( "quit" ) )
                .click = delegate ( Widget w )
                {
                    el.remove( e );
                    update;
                    return true;
                };
            // エフェクトプロパティ表示 or 非表示
            main.clickable( true )
                .click = delegate ( Widget w )
                {
                    e.propertiesOpened = !e.propertiesOpened;
                    panel.visibility = e.propertiesOpened ?
                        Visibility.Visible : Visibility.Gone;
                    update( false );
                    return true;
                };
            panel.visibility = e.propertiesOpened ?
                Visibility.Visible : Visibility.Gone;
        }
}

/+ プロパティ編集 +/
private class PropertyPanel : VerticalLayout
{
    enum SwitchStyle   = "PROPERTY_EDITOR_SWITCH";
    enum InputStyle_SL = "PROPERTY_EDITOR_INPUT_SL";
    enum InputStyle_ML = "PROPERTY_EDITOR_INPUT_ML";
    private:
        PropertyList props;
        FrameAt frame;

        Widget createWidget ( Property p )
        {
            switch ( p.typeToString ) {
                case "bool":
                    auto w = new SwitchButton;
                    w.styleId = SwitchStyle;
                    w.checked = p.getString( frame ).to!bool;
                    w.checkChange = delegate ( Widget w, bool f )
                    {
                        p.setString( frame, f.to!string );
                        return true;
                    };
                    return w;
                default:
                    auto w     = p.allowMultiline ? new EditBox   : new EditLine;
                    w.styleId  = p.allowMultiline ? InputStyle_ML : InputStyle_SL;

                    w.text = p.getString( frame ).to!dstring;
                    w.focusChange = delegate ( Widget w, bool f )
                    {
                        auto new_text = p.getString( frame ).to!dstring;
                        if ( w.text != new_text ) w.text = new_text;
                        return true;
                    };
                    w.contentChange = delegate ( EditableContent e )
                    {
                        auto new_text = w.text.to!string;
                        auto now_text = p.getString( frame );
                        try {
                            if ( new_text != now_text )
                                p.setString( frame, new_text );
                        } catch ( Exception e ) {
                            w.text = now_text.to!dstring;
                        }
                    };
                    return w;
            }
        }

        void addProperty ( Property p, string name )
        {
            addChild( new TextWidget( "", name.to!dstring ) );
            with ( addChild( new HorizontalLayout ).layoutWidth( FILL_PARENT ) ) {
                addChild( new HSpacer );
                addChild( createWidget( p ) );
                addChild( new HSpacer );
            }
        }

    public:
        this ( PropertyList p, FrameAt f )
        {
            super();
            props = p;
            frame = f;
            updateWidgets;
        }

        void updateWidgets ()
        {
            removeAllChildren;
            foreach ( k,v; props.properties )
                addProperty( v, k );
            invalidate;
        }
}
