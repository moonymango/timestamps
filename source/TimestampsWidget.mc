
import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Graphics;
import Toybox.Attention;

// timestamp categories
const categories = { "red" => Graphics.COLOR_RED, "blue" => Graphics.COLOR_BLUE, "green" => Graphics.COLOR_GREEN, "yellow" => Graphics.COLOR_YELLOW };

function formatTime(mt as Time.Moment) as String {
    var info = Gregorian.info(mt, Time.FORMAT_LONG);
    return Lang.format("$1$:$2$:$3$", [info.hour.format("%02d"), info.min.format("%02d"), info.sec.format("%02d")]);
}

function formatDate(mt as Time.Moment) as String {
    var info = Gregorian.info(mt, Time.FORMAT_LONG);
    return Lang.format("$1$. $2$ $3$", [info.day, info.month, info.year]);
}


// menu to show all stored timestamps using menu2
class TimestampList extends WatchUi.Menu2 {

    public static var listValid as Boolean = true;

    public function initialize() {
        Menu2.initialize({:title=>"Timestamps"});

        // create menu items based on stored timestamp
        var lst = Storage.getValue("timestamps");

        if ((lst == null) || (lst.size() == 0)) {
            // list empty -> just create a dummy entry (note: item id must not be a valid list index to differentiate from real entries)
            self.addItem(new WatchUi.MenuItem( "no entries", "", "dummy", null) );
        } else {
            // create one menu item for each timestamp
            for( var i = 0; i < lst.size(); i++ ) {
                var idx = lst.size()-1-i;    // show list in reversed order (newest timestamp first)
                var mt = new Time.Moment(lst[idx][0]);
                var color = lst[idx][1];

                // use index of timestamp entry as menu item id -> to be used later when user selects a menu item to delete the timestamp
                self.addItem(new WatchUi.IconMenuItem( $.formatTime(mt), $.formatDate(mt), idx, new $.Fill(color), null) );   
            }
        }
    }

    function onShow() as Void {
        Menu2.onShow();

        // if list is not valid anymore -> recreate
        if (!listValid) {
            listValid = true;
            WatchUi.switchToView(new $.TimestampList(), new $.TimestampListSelectionDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}


class TimestampsWidget extends Application.AppBase {
    var now as Time.Moment;  // next timestamp to create

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {}
    public function onStop(state as Dictionary?) as Void {}

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

    function onShow() as Void {}
    function onHide() as Void {}

    function onUpdate(dc as Dc) as Void {

        // show timestamp which can be added to timestamp list next
        var app = Application.getApp();
        app.now = Time.now();
        var timeString = "Set?\n" + $.formatTime(app.now) + "\n" + $.formatDate(app.now);

        var view = View.findDrawableById("TimeLabel") as Text; 
        view.setText(timeString);
        View.onUpdate(dc);
    }
}


class StartScreenInputDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    function onTap(clickEvent) {
        var sub = $.formatDate(Application.getApp().now);
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
        WatchUi.pushView(new $.TimestampList(), new TimestampListSelectionDelegate(), WatchUi.SLIDE_LEFT);
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

        // feedback to user that timestamp is saved
        if (Attention has :vibrate) {
            var vibeData =
            [
                new Attention.VibeProfile(100, 200), 
                new Attention.VibeProfile(25, 100), 
                new Attention.VibeProfile(100, 200), 
            ];
            Attention.vibrate(vibeData);
        }

        // show list of all saved timestamps
        WatchUi.switchToView(new $.TimestampList(), new TimestampListSelectionDelegate(), WatchUi.SLIDE_UP);
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

        // for a real entry create confirmation dialog to let user confirm delete
        var label = "Delete " + item.getLabel() + "?";
        WatchUi.pushView(new WatchUi.Confirmation(label), new $.ConfirmationDialogDelegate(idx), WatchUi.SLIDE_IMMEDIATE);
    }
}


class ConfirmationDialogDelegate extends WatchUi.ConfirmationDelegate {
    var _entryIdx as Number;

    public function initialize(entryIdx as Number) {
        ConfirmationDelegate.initialize();
        _entryIdx = entryIdx;
    }

    public function onResponse(value as Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            // delete entry from list 
            var lst = Storage.getValue("timestamps");
            if (_entryIdx < lst.size()) {
                var entry = lst[_entryIdx];
                lst.remove(entry);
                Storage.setValue("timestamps", lst);

                // feedback to user that timestamp was deleted
                if (Attention has :vibrate) {
                    var vibeData =
                    [
                        new Attention.VibeProfile(100, 200), 
                        new Attention.VibeProfile(25, 100), 
                        new Attention.VibeProfile(100, 200), 
                    ];
                    Attention.vibrate(vibeData);
                }
            
                // set invalid flag to update timestamp list view
                $.TimestampList.listValid = false;
            }
        }
        return true;
    }
}


// Drawable that fills the draw context with specified color.
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