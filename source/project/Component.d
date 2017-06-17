/+ ------------------------------------------------------------ +
 + Author : aoitofu <aoitofu@dr.com>                            +
 + This is part of CAFE ( https://github.com/aoitofu/CAFE ).    +
 + ------------------------------------------------------------ +
 + Please see /LICENSE.                                         +
 + ------------------------------------------------------------ +/
module cafe.project.Component;
import cafe.project.timeline.Timeline,
       cafe.project.ObjectPlacingInfo,
       cafe.project.RenderingInfo,
       cafe.renderer.graphics.Bitmap,
       cafe.renderer.World,
       cafe.renderer.Renderer;
import std.algorithm;

debug = 0;

/+ プロジェクト内のコンポーネントデータ +
 + AULでいうシーン                      +/
class Component
{
    private:
        Timeline tl;

    public:
        @property timeline () { return tl; }

        this ( Component src )
        {
            tl = new Timeline( src.timeline );
        }

        this ()
        {
            tl = new Timeline;
        }

        /+ RenderingInfoを生成 +/
        auto generate ( FrameAt f )
        {
            auto rinfo   = new RenderingInfo( f );
            auto objects = timeline.objectsAtFrame(f).sort!
                ( (a, b) => a.place.layer.value < b.place.layer.value );
            objects.each!( x => x.apply( rinfo ) );
            return rinfo;
        }

        /+ レンダリング +/
        RenderingResult render ( FrameAt f, Renderer r )
        {
            auto rinfo = generate(f);
            return r.render( rinfo.renderingStage, rinfo.camera );
        }

        debug (1) unittest {
            auto hoge = new Component;
            assert( hoge.generate( new FrameAt(0) ).renderingStage.polygons.length == 0 );
            // hoge.render( new FrameAt(0) );
        }
}
