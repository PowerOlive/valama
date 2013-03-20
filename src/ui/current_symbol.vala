/*
 * src/ui/current_symbol.vala
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
using Vala;

/**
 * Show current file's basic structure
 */
public class UiCurrentSymbol : UiElement {

    public UiCurrentSymbol () {
        var vbox = new Box (Orientation.VERTICAL, 0);

        var toolbar_title = new Toolbar ();
        toolbar_title.get_style_context().add_class (STYLE_CLASS_PRIMARY_TOOLBAR);
        var ti_title = new ToolItem();
        ti_title.add (new Label (_("Current symbol")));
        toolbar_title.add(ti_title);

        var separator_stretch = new SeparatorToolItem();
        separator_stretch.set_expand (true);
        separator_stretch.draw = false;
        toolbar_title.add (separator_stretch);
        vbox.pack_start (toolbar_title, false, true);

        project.completion_finished.connect ((smb)=>{
            current_symbol = smb;
            build();
        });

        vbox.pack_start (container, true, true);

        vbox.show_all();

        widget = vbox;
    }

    Symbol? current_symbol;
    Box container = new Box (Orientation.VERTICAL, 0);
    Box internal_widget;

    protected override void build() {
        debug_msg (_("Run %s update!\n"), get_name());
        if (internal_widget != null)
            container.remove (internal_widget);
        internal_widget = new Box (Orientation.VERTICAL, 0);
        container.pack_start (internal_widget, true, true);

        if (current_symbol == null) {
            var lbl_no_sym = new Label (_("No current symbol"));
            lbl_no_sym.sensitive = false;
            internal_widget.pack_start (lbl_no_sym, true, true);
        } else {
            /*var lbl_heading = new Label (current_symbol.name);
            lbl_heading.halign = Align.START;
            internal_widget.pack_start (lbl_heading, false, true);*/
            if (current_symbol is Vala.Signal) {
                var sgn = current_symbol as Vala.Signal;
                var lbl_params = new Label ("");
                lbl_params.use_markup = true;
                lbl_params.halign = Align.START;
                lbl_params.valign = Align.START;
                lbl_params.wrap = true;
                lbl_params.wrap_mode = Pango.WrapMode.WORD;
                lbl_params.label += """<span font="Monospace">""";
                lbl_params.label += "<b>" + Markup.escape_text (sgn.name) + "</b> (";

                var prms = sgn.get_parameters();
                for (int q = 0; q < prms.size; q++) {
                    if (prms[q].direction == ParameterDirection.OUT)
                        lbl_params.label += """<span color="#A52A2A"><b>out</b></span> """;
                    else if (prms[q].direction == ParameterDirection.REF)
                        lbl_params.label += """<span color="#A52A2A"><b>ref</b></span> """;
                    lbl_params.label += """<span color="#79b594">"""
                                        + Markup.escape_text (prms[q].variable_type.data_type.name
                                        + "</span> " + Markup.escape_text (prms[q].name));
                    if (q < prms.size - 1)
                        lbl_params.label += ", ";
                }
                lbl_params.label += ")</span>";

                internal_widget.pack_start (lbl_params, true, true);
            }
            if (current_symbol is Method) {
                var mth = current_symbol as Method;

                //TODO: Fix strange Pango markup warnings

                var lbl_params = new Label ("");
                lbl_params.use_markup = true;
                lbl_params.halign = Align.START;
                lbl_params.valign = Align.START;
                lbl_params.wrap = true;
                lbl_params.wrap_mode = Pango.WrapMode.WORD;
                lbl_params.label += """<span font="Monospace"><span color="#79b594">""";
                if (mth.return_type.data_type != null)
                    lbl_params.label += Markup.escape_text (mth.return_type.data_type.name);
                else
                    lbl_params.label += "void";
                lbl_params.label += "</span> <b>" + Markup.escape_text (mth.name) + "</b> (";

                var prms = mth.get_parameters();
                for (int q = 0; q < prms.size; q++) {
                    if (prms[q].direction == ParameterDirection.OUT)
                        lbl_params.label += """<span color="#A52A2A"><b>out</b></span> """;
                    else if (prms[q].direction == ParameterDirection.REF)
                        lbl_params.label += """<span color="#A52A2A"><b>ref</b></span> """;
                    lbl_params.label += """<span color="#79b594">"""
                                        + Markup.escape_text (prms[q].variable_type.data_type.name)
                                        + "</span> " + Markup.escape_text (prms[q].name);
                    if (q < prms.size - 1)
                        lbl_params.label += ", ";
                }

                lbl_params.label += ")</span>";
                if (mth.comment != null)
                    lbl_params.label += "\n\n" + Markup.escape_text (mth.comment.content);
                internal_widget.pack_start (lbl_params, true, true);
            }
        }
        internal_widget.show_all();
        debug_msg (_("%s update finished!\n"), get_name());
    }
}


// vim: set ai ts=4 sts=4 et sw=4