/+ ------------------------------------------------------------ +
 + Author : aoitofu <aoitofu@dr.com>                            +
 + This is part of CAFE ( https://github.com/aoitofu/CAFE ).    +
 + ------------------------------------------------------------ +
 + Please see /LICENSE.                                         +
 + ------------------------------------------------------------ +/
module cafe.gui.controls.PropertyEditor;
import cafe.project.ObjectPlacingInfo,
       cafe.project.timeline.PlaceableObject,
       cafe.project.timeline.property.Property,
       cafe.project.timeline.property.PropertyList;
import std.algorithm,
       std.conv;
import dlangui,
       dlangui.widgets.metadata;

mixin( registerWidgets!PropertyEditor );

/+ プロパティを編集するウィジェット +/
class PropertyEditor : VerticalLayout
{
    private:
        PlaceableObject obj;

    public:
        @property object () { return obj; }
        @property object ( PlaceableObject o )
        {
            obj = o;
            updateWidgets;
        }

        this ( string id = "" )
        {
            super( id );

            // TODO test
            import cafe.project.timeline.custom.NullObject;
            object = new NullObject( new ObjectPlacingInfo( new LayerId(0),
                        new FramePeriod( new FrameLength(100), new FrameAt(0), new FrameLength(50) ) ) );
        }

        void updateWidgets ()
        {
            removeAllChildren;
            if ( object ) {
                addChild( new GroupPanelFrame( object.propertyList, object.name ) );
                object.effectList.effects.each!
                    ( x => addChild( new GroupPanelFrame( x.propertyList, x.name ) ) );
            }
            invalidate;
        }
}

/+ 一つのグループの外枠 +/
private class GroupPanelFrame : VerticalLayout
{
    enum HeaderLayout = q{
        HorizontalLayout {
            layoutWidth:FILL_PARENT;
            HSpacer {}
            TextWidget { id:header; styleId:PROPERTY_EDITOR_GROUP_HEADER; fontSize:16 }
            HSpacer {}
            ImageWidget { id:shrink; drawableId:move_behind; }
        }
    };

    private:
        PropertyPanel panel;

    public:
        this ( PropertyList l, string title )
        {
            super();
            margins = Rect( 5, 5, 5, 5 );
            padding = Rect( 5, 5, 5, 5 );

            addChild( parseML(HeaderLayout) );
            panel = cast(PropertyPanel)addChild( new PropertyPanel( l ) );

            childById( "header" ).text = title.to!dstring;
            childById( "shrink" ).mouseEvent = delegate ( Widget w, MouseEvent e )
            {
                if ( e.action == MouseAction.ButtonDown && e.button & MouseButton.Left ) {
                    panel.visibility = panel.visibility == Visibility.Visible ?
                        Visibility.Gone : Visibility.Visible;
                    invalidate;
                    return true;
                } else return false;
            };
        }
}

/+ プロパティ編集 +/
private class PropertyPanel : VerticalLayout
{
    private:
        PropertyList props;

        void addProperty ( Property p, string name )
        {
            // TODO test
            auto frame = new FrameAt(0);

            addChild( new TextWidget( "", name.to!dstring ) );

            auto l = addChild( new HorizontalLayout );
            l.layoutWidth = FILL_PARENT;
            l.addChild( new HSpacer );
            auto input = cast(EditWidgetBase)l.addChild( p.allowMultiline ?
                    new EditBox( name ) : new EditLine( name ) );
            l.addChild( new HSpacer );

            input.minWidth = 200;
            input.text = p.getString( frame ).to!dstring;
            input.contentChange = delegate ( EditableContent e )
            {
                p.setString( frame, e.text.to!string );
            };
        }

    public:
        this ( PropertyList p )
        {
            super();
            props = p;
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