/*
 * src/ui_source_viewer.vala
 * Copyright (C) 2013, Valama development team
 *
 * Valama is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Valama is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;
using Gtk;
using Gdl;
using Gee;

/**
 * Report build status and code warnings/errors.
 */
class UiSourceViewer : UiElement {

    public UiSourceViewer() {
        this.srcdock.master.switcher_style = SwitcherStyle.TABS;
        this.srclayout = new DockLayout (this.srcdock);
        var box = new Box (Orientation.HORIZONTAL, 0);
        box.pack_end (this.srcdock);

        /* Don't make source view dockable. */
        dock_item = new DockItem ("SourceView",  _("Source"),
                                    DockItemBehavior.NO_GRIP |
                                    DockItemBehavior.CANT_DOCK_CENTER);
        dock_item.add (box);
    }
    public DockItem dock_item;
    /**
     * Source code dock.
     */
    private Dock srcdock = new Dock();
    /**
     * Layout of source code dock {@link srcdock}.
     */
    private DockLayout srclayout;

    /**
     * List of all {@link DockItem} objects in source dock {@link srcdock}.
     */
    private ArrayList<DockItem> srcitems = new ArrayList<DockItem>();


    private string? _current_srcfocus = null;
    /**
     * Relative path to current selected {@link SourceBuffer}.
     */
    public string current_srcfocus {
        get {
            return _current_srcfocus;
        }
        private set {
            debug_msg (_("Change current focus: %s\n"), value);
            this._current_srcfocus = value;
            this.current_srcid = get_sourceview_id (this._current_srcfocus);
            if (0 <= this.current_srcid < this.srcitems.size) {
                this.current_srcview = get_sourceview (this.srcitems[this.current_srcid]);
                this.current_srcbuffer = (SourceBuffer) this.current_srcview.buffer;
            } else
                errmsg (_("Warning: Could not select current source view: %s\n" +
                                 "Expected behavior may change.\n"), this._current_srcfocus);
        }
    }
    /**
     * Id of current {@link Gtk.SourceView} in {@link srcitems}.
     */
    private int current_srcid { get; private set; default = -1; }
    /**
     * Currently selected {@link Gtk.SourceView}.
     */
    public SourceView? current_srcview { get; private set; default = null; }
    /**
     * Currently selected {@link SourceBuffer}.
     */
    public SourceBuffer? current_srcbuffer { get; private set; default = null; }

    /**
     * Focus source view {@link Gdl.DockItem} in {@link Gdl.Dock} and select
     * recursively all {@link Gdl.DockNotebook} tabs.
     *
     * @param filename Name of file to focus.
     */
    public void focus_src (string filename) {
        foreach (var srcitem in srcitems) {
            if (srcitem.long_name == filename) {
                /* Hack arround gdl_dock_notebook with gtk_notebook. */
                var pa = srcitem.parent;
                // pa.grab_focus();
                /* If something strange happens (pa == null) break the loop. */
                while (!(pa is Dock) && (pa != null)) {
                    //msg ("item: %s\n", pa.name);
                    if (pa is Switcher) {
                        var nbook = (Notebook) pa;
                        nbook.page = nbook.page_num (srcitem);
                    }
                    pa = pa.parent;
                    // pa.grab_focus();
                }
                return;
            }
        }
    }

    /**
     * Connect to this signal to interrupt hiding (closing) of
     * {@link Gdl.DockItem} with {@link Gtk.SourceView}.
     *
     * @param view {@link Gtk.SourceView} to close.
     * @return Return false to interrupt or return true proceed.
     */
    public signal bool buffer_close (SourceView view);

    /**
     * Hide (close) {@link Gdl.DockItem} with {@link Gtk.SourceView} by
     * filename.
     *
     * @param filename Name of source file to close.
     */
    public void close_srcitem (string filename) {
        foreach (var srcitem in srcitems)
            if (srcitem.long_name == filename) {
                srcitems.remove (srcitem);
                srcitem.hide_item();
            }
    }

    /**
     * Add new source view item to source dock {@link srcdock}.
     *
     * @param view {@link Gtk.SourceView} object to add.
     * @param filename Name of file (used to identify item).
     */
    public void add_srcitem (SourceView view, string filename = "") {
        if (filename == "")
            filename = _("New document");

        var src_view = new ScrolledWindow (null, null);
        src_view.add (view);

        var srcbuf = (SourceBuffer) view.buffer;
        var attr = new SourceMarkAttributes();
        attr.stock_id = Stock.MEDIA_FORWARD;
        view.set_mark_attributes ("timer", attr, 0);
        var attr2 = new SourceMarkAttributes();
        attr2.stock_id = Stock.STOP;
        view.set_mark_attributes ("stop", attr2, 0);
        view.show_line_marks = true;
        srcbuf.create_tag ("error_bg", "underline", Pango.Underline.ERROR, null);
        srcbuf.create_tag ("warning_bg", "background", "yellow", null);
        srcbuf.create_tag ("search", "background", "blue", null);

        //"left-margin", "1", "left-margin-set", "true",
        /*
         * NOTE: Keep this in sync with get_sourceview method.
         */
        var item = new DockItem.with_stock ("SourceView " + srcitems.size.to_string(),
                                            filename,
                                            (srcbuf.dirty) ? Stock.NEW : Stock.EDIT,
                                            DockItemBehavior.LOCKED);
        srcbuf.notify["dirty"].connect ((sender, property) => {
            item.stock_id = (srcbuf.dirty) ? Stock.NEW : Stock.EDIT;
        });
        item.add (src_view);

        /* Set focus on tab change. */
        item.selected.connect (() => {
            this.current_srcfocus = filename;
        });
        /* Set focus on click. */
        view.grab_focus.connect (() => {
            this.current_srcfocus = filename;
        });


        if (srcitems.size == 0) {
            this.srcdock.add_item (item, DockPlacement.RIGHT);
        } else {
            /* Handle dock item closing. */
            item.hide.connect (() => {
                /* Suppress dialog by removing item at first from srcitems list. */
                if (!(item in srcitems))
                    return;

                if (!buffer_close (get_sourceview (item))) {
                    /*
                     * This will work properly with gdl-3.0 >= 3.5.5
                     */
                    item.show_item();
                    set_notebook_tabs (item);
                    return;
                }
                srcitems.remove (item);
                if (srcitems.size == 1)
                    srcitems[0].show_item();
            });

            item.behavior = DockItemBehavior.CANT_ICONIFY;

            /*
             * Hide default source view if it is empty.
             * Dock new items to focused dock item.
             *
             * NOTE: Custom unsafed views are ignored (even if empty).
             */
            int id = 0;
            if (this.current_srcfocus != null)
                id = get_sourceview_id (this.current_srcfocus);
            if (id != -1)
                this.srcitems[id].dock (item, DockPlacement.CENTER, 0);
            else {
                bug_msg (_("Source view id out of range.\n"));
                return;
            }
            if (srcitems.size == 1) {
                var view_widget = get_sourceview (srcitems[0]);
                //TODO: Use dirty flag of buffer.
                if (view_widget.buffer.text == "")
                    srcitems[0].hide_item();
            }
        }
        srcitems.add (item);
        item.show_all();

        /*
         * Set notebook tab properly if needed.
         */
        item.dock.connect (() => {
            set_notebook_tabs (item);
        });

    }

    /**
     * Set up {@link Gtk.Notebook} tab properties.
     *
     * @param item {@link Gdl.DockItem} to setup.
     */
    private void set_notebook_tabs (DockItem item) {
        var pa = item.parent;
        if (pa is Switcher) {
            var nbook = (Notebook) pa;
            nbook.set_tab_pos (PositionType.TOP);
            foreach (var child in nbook.get_children())
                nbook.set_tab_reorderable (child, true);
        }
    }

    /**
     * Get {@link Gtk.SourceView} from within {@link Gdl.DockItem}.
     *
     * @param item {@link Gdl.DockItem} to get {@link Gtk.SourceView} from.
     * @return Return associated {@link Gtk.SourceView}.
     */
    /*
     * NOTE: Be careful. This have to be exactly the same objects as the
     *       objects at creation of new source views.
     */
    private SourceView get_sourceview (DockItem item) {
#if VALAC_LESS_0_20
        /*
         * Work arround GNOME #693127.
         */
        ScrolledWindow scroll_widget = null;
        item.forall ((child) => {
            if (child is ScrolledWindow)
                scroll_widget = (ScrolledWindow) child;
        });
        if (scroll_widget == null)
            bug_msg (("Could not find ScrolledWindow widget: %s\n"), item.name);
#else
        var scroll_widget = (ScrolledWindow) item.get_child();
#endif
        return (SourceView) scroll_widget.get_children().nth_data (0);
    }

    /**
     * Get id of {@link Gtk.SourceView} by filename.
     *
     * @param filename Name of source file to search for in {@link srcitems}.
     * @return If file was found return id of {@link Gtk.SourceView} in
     *         {@link srcitems}. Else -1.
     */
    private int get_sourceview_id (string filename) {
        for (int i = 0; i < srcitems.size; ++i)
            if (srcitems[i].long_name == filename)
                return i;
        debug_msg ("No such file found in opened buffers: %s\n", filename);
        return -1;
    }

    public SourceView? get_sourceview_by_file (string filename) {
        var id = get_sourceview_id(filename);
        if (id == -1)
            return null;
        return get_sourceview (this.srcitems[id]);
    }

    public override void build() {
        debug_msg (_("Run %s update!\n"), element_name);
        debug_msg (_("%s update finished!\n"), element_name);
    }
}
