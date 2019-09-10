//TODO:
// handle overbooked situation

import ballerina/grpc;
import ballerina/io;
import ballerina/log;

listener grpc:Listener ep = new (9090);
// capacity of three tables at the same time
int count = 0;
json reservation = [];
json booking = [];
// should be sorted from greatest deposit to least
DepositDetails[] overbooks = [];
int bcount = 0;
string[3] tables = ["T1", "T2", "T3"];
string[] cantGet = [];
int cg = 0;// count cant get tables
int cd = 0;// count different dates
float MINIMUM_DEPOSIT_AMOUNT = 300;

function isAvailable(BookingId bd) returns (boolean, string) {

    int i = bd.bd.duration;
    int hour = i / 3600;
    int min = (i % 3600) / 60;
    hour = bd.bd.time.hour + hour;
    if (hour > 24) {
        hour = hour - 24;
    }
    min = bd.bd.time.min + min;
    if (min > 59) {
        min = min - 60;
    }

    string date = bd.bd.date.day + "-" + bd.bd.date.month + "-" + bd.bd.date.year;
    json b = {
        bookingId: bd.bookingId,
        fromTime: bd.bd.time.hour + ":" + bd.bd.time.min,
        toTime: hour + ":" + min,
        gotTable: "no"
    };

    if (booking.length() > 0) {
        foreach var item in 0 ... booking.length() - 1 {

            if (date.equalsIgnoreCase(booking[item].date.toString())) {
                cd = cd + 1;
                foreach var r in 0 ... booking[item].details.length() - 1 {
                    int | error endHour = int.convert(booking[item].details[r].toTime.toString().split(":")[0]);
                    int | error endMin = int.convert(booking[item].details[r].toTime.toString().split(":")[1]);

                    int | error startHour = int.convert(b.fromTime.toString().split(":")[0]);
                    int | error startMin = int.convert(b.fromTime.toString().split(":")[1]);

                    if (startHour is int && startMin is int && endHour is int && endMin is int) {
                        if (startHour < endHour || ((startHour == endHour) && startMin <= endMin)) {
                            cantGet[cg] = booking[item].details[r].gotTable.toString();
                            //io:println("table: ", booking[item].details[r].gotTable.toString());
                            cg = 1 + cg;
                        }
                    }
                }
                if (cg == 0) {
                    b.gotTable = "T1";                    // GIVE T1 BY DEFAULT
                    booking[item].details[booking[item].details.length()] = b;
                }
                else {
                    foreach var tb in 0 ... tables.length() - 1 {
                        int ct = 0;
                        foreach var nt in 0 ... cantGet.length() - 1 {
                            if (tables[tb].equalsIgnoreCase(cantGet[nt])) {
                                ct = 1 + ct;
                            }
                        }
                        if (ct == 0) {
                            b.gotTable = tables[tb];
                        }
                        ct = 0;
                    }
                    if (b.gotTable.toString().equalsIgnoreCase("no")) {
                        //io:println("Overbook situation....\n forward to deposit function please...");
                        // implement the deposit function
                        return (false, "");
                    }
                    else {
                        booking[item].details[booking[item].details.length()] = b;
                        //io:println("got this far");
                        return (true,b.gotTable.toString());
                    }
                }
                cg = 0;
                cantGet = [];
            }
        }

        if (cd == 0) {
            b.gotTable = "T1";            // T1 BY DEFAULT
            int l = booking.length();
            booking[booking.length()] = {
                date: date,
                details: [b]
            };
        }
        cd = 0;
        return (true,b.gotTable.toString());
    }
    else {
        booking[0] = {
            date: "",
            details: []
        };

        booking[0].date = date;
        b.gotTable = tables[0];
        booking[0].details[0] = b;
        bcount = bcount + 1;
        return (true,b.gotTable.toString());
    }

    

}

public function sortOverbooks() {
    foreach int i in 0 ..< overbooks.length() {
        int j = i;
        while (j < overbooks.length()) {
            if (overbooks[j].depositAmount > overbooks[i].depositAmount) {
                // swap
                float c = overbooks[j].depositAmount;
                overbooks[j].depositAmount = overbooks[i].depositAmount;
                overbooks[i].depositAmount = c;
            }
            j += 1;
        }
    }
}
service kent on ep {

    resource function book(grpc:Caller caller, BookingDetails value) {
        // Implementation goes here.
        count = count + 1;
        BookingId bId = {
            bookingId: "b" + count,
            bd: value
        };
        error? result = ();
        map<any> b = {
            "b" + count: bId.bd
        };
        json | error a =  json.convert(b);
        if (a is json) {
            reservation[count - 1] = a;
        }
        (boolean, string) available = isAvailable(bId);
        BookingResponse br = {
            bookingId: bId,
            conf: {
                confirmed: true
            },
            tableAssigned: ""
        };
        io:println("\n", booking, "\n\n");
        //io:println(available[1]);
        if (available[0] == false) {
            br.conf.confirmed = false;
        }

        // You should return a BookingResponse
        result = caller->send(br);
        result = caller->complete();

    }

    resource function deposit(grpc:Caller caller, DepositDetails dd) {
        error? result;
        Confirmation c = {
            confirmed: false
        };
        // check deposit amount
        if (dd.depositAmount >= MINIMUM_DEPOSIT_AMOUNT) {
            overbooks[overbooks.length()] = dd;
            c.confirmed = true;
        }
        
        result = caller->send(c);
        result = caller->complete();
        sortOverbooks();
        // foreach var item in overbooks {
        //     io:println(item.depositAmount);
        // }
        io:println("------------Deposit here---------------------------");
        

    }
}
