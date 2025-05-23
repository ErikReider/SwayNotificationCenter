namespace SwayNotificationCenter.Widgets.Todo {
    public struct Config {
        string todo;
    }
    
    public struct TodoSource {
        string class;
        string assignment;
        string title;
        string due;
        string type;
        string color;
    }

    public class Todo: BaseWidget  {
        public override string widget_name {
            get {
                return "todo";
            }
        }

        // Gtk.Label todo_widget;
        // Gtk.Button clear_all_button;
        Gtk.ScrolledWindow big_box;
        Gtk.Box small_box;
        Json.Node colorsJSON;

        HashTable<string, TodoItem> todo_items = new HashTable<string, TodoItem> (str_hash, str_equal);


        // Default config values
        Config todo_config = Config () {
            todo = "RATS"
        };
        public int hexval( string c ) {
            switch(c) {
                case "a":
                return 10;
                case "b":
                return 11;
                case "c":
                return 12;
                case "d":
                return 13;
                case "e":
                return 14;
                case "f":
                return 15;
                default:
                return int.parse(c);
            }
        }
        public int hextoint(string hex){
            //convert the string to lowercase
            string hexdown = hex.down();
            //get the length of the hex string
            int hexlen = hex.length;
            int ret_val = 0;
            string chr;
            int chr_int;
            int multiplier;
            
            //loop through the string 
            for (int i = 0; i < hexlen ; i++) {
                //get the string chars from right to left
                int inv = (hexlen-1)-i;
                chr = hexdown[inv:inv+1];
                chr_int = hexval(chr);
                
                //how are we going to multiply the current characters value?
                multiplier = 1;
                for(int j = 0 ; j < i ; j++) {
                multiplier *= 16;
                }
                ret_val += chr_int * multiplier;
            }
            return ret_val;
        }

        public Json.Node getFile(string path) {
            var file = File.new_for_path (path);
            var dis = new DataInputStream (file.read ());
            string line = dis.read_line (null);
            Json.Parser parser = new Json.Parser ();
            try {
                parser.load_from_data (line);
            } catch (Error e) {
                print("unable to parse JSON: %s\n", e.message);
            }
            
            // Get the root node:
            return parser.get_root ();
        }


        public Json.Node getHTTP( string host, string path ) {
            // Resolve hostname to IP address
            var resolver = Resolver.get_default ();
            var addresses = resolver.lookup_by_name (host, null);
            var address = addresses.nth_data (0);
            print (@"Resolved $host to $address\n");

            // Connect
            var client = new SocketClient ();
            // client.tls = true;
            client.set_tls(true);
            client.event.connect ((event, connectable, connection) => {
                if (event == SocketClientEvent.TLS_HANDSHAKING) {
                    ((TlsClientConnection) connection).accept_certificate.connect ((peer_cert, errors) => {
                        return true;
                    });
                }
            });
            var conn = client.connect (new InetSocketAddress (address, 443));
            print (@"Connected to $host\n");

            // Send HTTP GET request
            var message = @"GET $path HTTP/1.1\r\nHost: $host\r\nAuthorization: Bearer 3123~eKn9wAQQYZBfcYnHZRRxMtzWRKH3XPyY769D6vmyLUxt3htNx2HTQvz8fvnyD7fm\r\n\r\n";
            conn.output_stream.write (message.data);
            print ("Wrote request\n");

            // Receive response
            var response = new DataInputStream (conn.input_stream);

            string line;

            while ((line = response.read_line (null)).length != 1) {
                // print ("Line Length: %i\n", line.length);
                // print ("Line: %s\n", line);
            }

            string bytes;
            string data = "";
            while ((bytes = response.read_line(null).strip()) != "0") {
                if (bytes == "0") {
                    print("done\n");
                    break;
                }
                if (bytes == "") {
                    continue;
                }
                uint8[] bts = new uint8[hextoint(bytes)];
                response.read_all(bts, null, null);
                //  print("data: %s\n",(string)bts);
                //  print("expected length: %s\n", bytes);
                //  print("read length: %i\n", ((string)bts).length);
                data += ((string)bts).substring(0, (long)hextoint(bytes));
            }
            response.close();
            //  if (data[0] == '{') {
            //      print("check for {\n");
            //      if (!data.has_suffix("}")) {
            //          print("Doesnt have }\n");
            //          data = data.substring(0,data.length-1);
            //      }
            //  } else if (data[0] == '[') {
            //      print("check for [\n");
            //      if (!data.has_suffix("]")) {
            //          print("doesnt have ]\n");
            //          data = data.substring(0,data.length-1);
            //          print("last char: %c\n", data[data.length]);
            //      }
            //  }
            

            Json.Parser parser = new Json.Parser ();
            try {
                parser.load_from_data (data);
            } catch (Error e) {
                print("unable to parse JSON: %s\n", e.message);
            }
            
            // Get the root node:
            return parser.get_root ();
        }

        public Todo (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.START);
            set_vexpand (false);

            big_box  = new Gtk.ScrolledWindow(null, null){
                visible = true,
            };

            big_box.set_vexpand(true);
            big_box.set_min_content_height (100);
            big_box.set_max_content_height (600);
            big_box.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
            
            small_box = new Gtk.Box(Gtk.Orientation.VERTICAL,0) {
                visible = true
            };
            small_box.set_vexpand(true);
            big_box.add(small_box);

            var host = "hcpss.instructure.com";
            
            colorsJSON = getHTTP(host, "/api/v1/users/self/colors");

	                
            
            add(big_box);



            // Config
            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get title
                string ? todo = get_prop<string> (config, "text");
                if (todo != null) todo_config.todo = todo;
            //     // Get has clear-all-button
            //     bool found_clear_all;
            //     bool? has_clear_all_button = get_prop<bool> (
            //         config, "clear-all-button", out found_clear_all);
            //     if (found_clear_all) this.has_clear_all_button = has_clear_all_button;
            //     // Get button text
            //     string? button_text = get_prop<string> (config, "button-text");
            //     if (button_text != null) this.button_text = button_text;
            }

            try {
                setup_todo.begin ();
            } catch (Error e) {
                error ("Todo Widget error: %s", e.message);
            }
        }

        private async void setup_todo () throws Error {
            ThreadFunc<bool> run = () => {

            var host = "hcpss.instructure.com";
            Json.Node todoJSON = getHTTP(host, "/api/v1/users/self/todo");
            //  Json.Node todoJSON = getFile("/home/10f7c7/Downloads/todo.json");
            string[] assignments = new string[todoJSON.get_array().get_length()];
            for (var i = 0; i < todoJSON.get_array().get_length(); i++) {
                // var item = new Gtk.Button.with_label(node.get_array().get_element(i).get_object().get_member("context_name").get_string());
                string assignment_id = "%i".printf((int)todoJSON.get_array().get_element(i).get_object().get_member("assignment").get_object().get_member("id").get_int());
                assignments[i] = assignment_id;
                if (check_item_exists (assignment_id)) continue;
                print("adding item: %s\n", assignment_id);
                TodoSource source = TodoSource () {
                    class = todoJSON.get_array().get_element(i).get_object().get_member("context_name").get_string(),
                    title = todoJSON.get_array().get_element(i).get_object().get_member("assignment").get_object().get_member("name").get_string(),
                    assignment = assignment_id,
                    due = todoJSON.get_array().get_element(i).get_object().get_member("assignment").get_object().get_member("due_at").get_string(),
                    type = "assignment",
                    color = colorsJSON.get_object().get_member("custom_colors").get_object().get_member("course_%i".printf((int)todoJSON.get_array().get_element(i).get_object().get_member("course_id").get_int())).get_string(),
                };
                if (todoJSON.get_array().get_element(i).get_object().get_member("assignment").get_object().get_member("submission_types").get_array().get_string_element(0) == "online_quiz") {
                    source.type = "quiz";
                }
                if (todoJSON.get_array().get_element(i).get_object().get_member("assignment").get_object().get_member("submission_types").get_array().get_string_element(0) == "external_tool") {
                    source.type = "lti";
                }   
                add_item(source, i);
            }
            purge_items(assignments);
            
            return true;
            };
            new Thread<bool>("thread-example", run);

            // Wait for background thread to schedule our callback
            yield;
        
    
        }
        
        private void purge_items(string[] assignments) {
            foreach (string assignment_check in todo_items.get_keys_as_array ()) {
                if (check_item_gone(assignment_check, assignments)){
                    remove_item(assignment_check);
                }
                
            }
        }

        private bool check_item_exists (string assignment) {
            foreach (string assignment_check in todo_items.get_keys_as_array ()) {
                if (assignment_check == assignment) {
                    print("item does exist: %s\n", assignment);
                    return true;
                };
            }
            print("item does not exist\n");
            return false;
        }

        private bool check_item_gone (string assignment, string[] assignments) {
            foreach (string assignment_check in assignments) {
                if (assignment_check == assignment) {
                    return false;
                    //  print("item does exist: %s\n", assignment);
                };
            }
            print("item does not exist\n");
            return true;
        }

        


        private void add_item(TodoSource source, int position) {
            TodoItem item = new TodoItem (source, todo_config);
            item.get_style_context ().add_class ("%s-item".printf (css_class_name));
            small_box.add(item);
            small_box.reorder_child(item, position);
            //  print("adding item: %s\n", source.assignment);
            todo_items.set (source.assignment, item);

            if (!visible) show ();
        }

        private void remove_item (string assignment) {
            string ? key;
            TodoItem ? item;
            bool result = todo_items.lookup_extended (assignment, out key, out item);
            if (!result || key == null || item == null) return;
            //  item.before_destroy ();
            item.destroy ();
            todo_items.remove (assignment);
        }

        public override void on_cc_visibility_change (bool value) {
            if (!value) return;
            setup_todo.begin();
            print("vis changed\n");
        }
    }
}

