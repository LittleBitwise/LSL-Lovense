string gObjectUrl;
string gIpAddress;
string gDomain;
string gToysJson;

list gHttpParams = [
    HTTP_METHOD, "POST",
    HTTP_MIMETYPE, "application/json",
    HTTP_VERIFY_CERT, FALSE
];

string HTML_BODY = "
<!DOCTYPE html>
<html><body>
<h2 style=\"text-align: center;\">Your HUD is about to connect<br />to your Lovense Remote!</h2>
<p style=\"text-align: center;\">Make sure the app is open <em>and</em><br />connected to the same Wi-Fi as your computer.<br />
<span style=\"color: #999999;\"><em>(in case you're using the app on your phone)</em></span></p>
<p style=\"text-align: center;\">If the HUD is unable to connect:<br />Make sure the ports are open in your router!<br />
<span style=\"color: #999999;\"><em>(You can see which ports and local IP are needed</em></span><br />
<span style=\"color: #999999;\"><em>when you enable Game Mode in Lovense Remote.)</em></span></p>
</body></html>
";

string TEXT_BODY = "
Your HUD is about to connect to your Lovense Remote!

Make sure Game Mode is enabled.

If you're using a mobile device:
Make sure it's connected to the same network as your computer.

If the HUD is unable to connect:
Make sure the ports are open in your router!
(You can see which ports and local IP are needed when you enable Game Mode in Lovense Remote.)
";

createMessage(list parts) {
    llOwnerSay((string)parts);
}

requestUrl() {
    createMessage(["Please wait a moment!"]);
    llRequestSecureURL();
}

getToys() {
    // todo: what if domain not set
    string json = llList2Json(JSON_OBJECT, ["command", "GetToys"]);
    llHTTPRequest(gDomain+"/command", gHttpParams, json);
}

pattern(float duration, float interval, list steps) {
    if (0 < duration && duration < 1) duration = 1;
    if (interval < 0.1) interval = 0.1;

    integer ms = (integer)(interval * 1000);
    integer stepCount = llGetListLength(steps);
    if (stepCount > 50) {
        createMessage([
            "Patterns can only use the first 50 steps! ",
            "(Had ", stepCount, ")"
        ]);
        steps = llList2List(steps, 0, 49);
        stepCount = 50;
    }

    // llOwnerSay(llList2CSV([
    //     duration, interval, stepCount
    // ]));

    // llOwnerSay(llList2CSV([
    //     "rule", "V:1;F:v;S:" + (string)ms + "#",
    //     "strength", llDumpList2String(steps, ";")
    // ]));

    string json = llList2Json(JSON_OBJECT, [
        "command", "Pattern",
        "rule", "V:1;F:v;S:" + (string)ms + "#",
        "strength", llDumpList2String(steps, ";"),
        "timeSec", duration,
        "apiVer", 1
    ]);
    llHTTPRequest(gDomain+"/command", gHttpParams, json);
}

list jsonGetkeys(string json) {
    list data = llJson2List(json);
    return llList2ListStrided(data, 0, -1, 2);
}

default
{
    state_entry()
    {
        requestUrl();
        llListen(0, "", "", "");
    }

    touch_start(integer n)
    {
        if (gObjectUrl == "") {
            requestUrl();
            return;
        }

        gToysJson = "";
        getToys();
    }

    listen(integer channel, string name, key id, string message)
    {
        if (id != llGetOwner()) return;

        list steps = llCSV2List(message);
        pattern(0, 0.3, steps);
    }

    http_response(key id, integer status, list metadata, string body)
    {
        // llOwnerSay((string)[
        //     "http_response status:", status,
        //     "http_response body: ", body
        // ]);

        if (status != 200) {
            createMessage([
                "Could not connect! (Code ",status,")"
            ]);
            if (status == 499) {
                createMessage([
                    "Make sure the app is on and in the same network as your computer, ",
                    "and that the correct ports are forwarded to your the device's local IP."
                ]);
            }
            return;
        }

        string bodyContentType = llJsonValueType(body, []);
        if (bodyContentType != JSON_OBJECT) {
            createMessage([
                "Could not read toy data! (Code ",status,")"
            ]);
            return;
        }

        string loveCode = llJsonGetValue(body, ["code"]);
        string loveType = llJsonGetValue(body, ["type"]);
        if (loveCode != "200") {
            createMessage([
                "love error! ",
                "(Code",loveCode,", Type: ",loveType,")"
            ]);
        }

        string dataToys = llJsonGetValue(body, ["data", "toys"]);
        if (dataToys != JSON_INVALID) {
            gToysJson = body;
            // llOwnerSay((string)[
            //     "Toy response saved"
            // ]);
            list toyKeys = jsonGetkeys(dataToys);
            integer toyCount = llGetListLength(toyKeys);

            list toys;
            integer i;
            for (i = 0; i < toyCount; ++i) {
                string value = llJsonGetValue(dataToys, (list)llList2String(toyKeys, i));
                // llOwnerSay((string)["toy ", i, ": ", value]);
                if (value == JSON_INVALID) jump break;
                if (value == JSON_NULL) jump break;
                toys += [
                    llJsonGetValue(value, ["name"]),
                    llJsonGetValue(value, ["id"])
                ];
            } @break;

            llOwnerSay("Toys: " + llList2CSV(toys));
            createMessage([
                llGetListLength(toys) / 2, " connected toys found!"
            ]);
        }
    }

    http_request(key id, string method, string body)
    {
        // llOwnerSay((string)[
        //     "http_request method: ", method, " ",
        //     "http_request body: ", body
        // ]);

        if (method == URL_REQUEST_GRANTED) {
            gObjectUrl = body;
            createMessage([
                "Ready! You can now ",
                "[",gObjectUrl," connect to Lovense Remote!]"
            ]);
            return;
        } else if (method == URL_REQUEST_DENIED) {
            createMessage([
                "Could't get a URL for this script! ",
                "You can try again by clicking the HUD.",
                "Reason: ", body
            ]);
            return;
        }

        if (gDomain == "") {
            gIpAddress = llGetHTTPHeader(id, "x-remote-ip");
            gDomain = (string)["https://",gIpAddress,":30010"];
        }

        llSetContentType(id, CONTENT_TYPE_TEXT);
        llHTTPResponse(id, 200, TEXT_BODY);

        getToys();

        // llOwnerSay(llList2CSV([
        //     "IP: ", gIpAddress,
        //     "Domain: ", gDomain,
        //     "JSON: ", json
        // ]));
    }
}
