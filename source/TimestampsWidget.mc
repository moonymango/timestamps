
import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Graphics;

// timestamp categories
const categories = { "red" => Graphics.COLOR_RED, "blue" => Graphics.COLOR_BLUE, "green" => Graphics.COLOR_GREEN, "yellow" => Graphics.COLOR_YELLOW };

// creates a view showing all stored timestamps using menu2
function createTimestampListView() as WatchUi.View {

    var menu = new WatchUi.Menu2({:title=>"Timestamps"});
    
    var lst = Storage.getValue("timestamps");
    if ((lst == null) || (lst.size() == 0)) {
        // list empty
        menu.addItem(new WatchUi.MenuItem( "no entries", "", "dummy", null) );
    } else {
       
        for( var i = 0; i < lst.size(); i++ ) {
            var idx = lst.size()-1-i;    // show list in reversed order (newest item first)
            var ts = new Time.Moment(lst[idx][0]);
            var info = Gregorian.info(ts, Time.FORMAT_LONG);
            var label = Lang.format("$1$:$2$:$3$", [info.hour.format("%02d"), info.min.format("%02d"), info.sec.format("%02d")]);
            var sub = Lang.format("$1$. $2$ $3$", [info.day, info.month, info.year]);

            var color = lst[idx][1];
            menu.addItem(new WatchUi.IconMenuItem( label, sub, idx, new $.Fill(color), null) );   // use index of entry as menu item id 
        }
    }

    return menu;
}

class TimestampsWidget extends Application.AppBase {

    var now as Time.Moment;  // common timestamp time for all views

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as Array<Views or InputDelegates>? {
        return [new $.StartScreen(), new $.StartScreenInputDelegate()] as Array<Views or InputDelegates>;
    }
}


class StartScreen extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.StartScreen(dc));
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {

        // show timestamp which can be added to timestamp list next
        var app = Application.getApp();
        app.now = Time.now();
        var info = Gregorian.info(app.now, Time.FORMAT_LONG);
        var timeString = "Set?\n" + Lang.format("$1$:$2$:$3$", [info.hour.format("%02d"), info.min.format("%02d"), info.sec.format("%02d")]);
        timeString += "\n" + Lang.format("$1$. $2$ $3$", [info.day, info.month, info.year]);

        var view = View.findDrawableById("TimeLabel") as Text; 
        view.setText(timeString);
        View.onUpdate(dc);
    }

    function onHide() as Void {
    }

}

class StartScreenInputDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    function onTap(clickEvent) {

        var info = Gregorian.info(Application.getApp().now, Time.FORMAT_MEDIUM);
        var sub = Lang.format("$1$:$2$:$3$", [info.hour.format("%02d"), info.min.format("%02d"), info.sec.format("%02d")]);
        var cnames = $.categories.keys();

        // create menu to select category (color) for the timestamp
        var menu = new WatchUi.Menu2({:title=>"Select Category"});
        for( var i = 0; i < cnames.size(); i++ ) {
            var c = cnames[i];
            var color = $.categories[c];
            menu.addItem(new WatchUi.IconMenuItem( c, sub, c, new $.Fill(color), null) );
        }

        WatchUi.pushView(menu, new $.CategorySelectionDelegate(), WatchUi.SLIDE_LEFT);
        
        return true;
    }

    function onHold(clickEvent) {
        // show list of saved timestamps
        WatchUi.pushView($.createTimestampListView(), new TimestampListSelectionDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}



class CategorySelectionDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        // create timestamp entry
        var color = $.categories[item.getId()];
        var entry = [Application.getApp().now.value(), color];
        
        // add entry to storage
        var lst = Storage.getValue("timestamps");
        if (lst == null) {
            lst = [entry];
        } else {
            lst.add(entry);
        }
        Storage.setValue("timestamps", lst);

        WatchUi.switchToView($.createTimestampListView(), new TimestampListSelectionDelegate(), WatchUi.SLIDE_UP);
    }
}

class TimestampListSelectionDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        // get entry index for selected menu item
        var idx = item.getId().toNumber();

        // dummy item only in empty list -> nothing to do, go to start screen
        if (idx == null) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        // for a real entry ask to confirm delete
        var lst = Storage.getValue("timestamps");
        var entry = lst[idx];
        if (entry != null) {
            // remove entry from storage and rebuild the list view
            lst.remove(entry);
            Storage.setValue("timestamps", lst);
            WatchUi.switchToView($.createTimestampListView(), new TimestampListSelectionDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
        
    }
}


class Fill extends WatchUi.Drawable {

    var _color as Number;

    public function initialize(color as Number) {
        Drawable.initialize({});
        _color = color;
    }

    public function draw(dc as Dc) as Void {
        dc.setColor(_color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
    }
}