// SPDX-License-Identifier: MIT
/*
* Batch: ACSE IITM August 2022
* Project: Problem Statement 3 - Blockchain based Ticket Management
* Developers: 
    Anuradha
    Reema
    Mohan
    Sachin Ghewde (SG) - <sachingg@hotmail.com>
* Description:
    ACSE IITM Capstone Project – Blockchain based Ticket Management - Eagle Airlines
    Goals
    •	Develop a Private Ethereum Blockchain implementation, using geth nodes running directly on a single AWS EC2 (Ubuntu) server.
    •	Use Clique PoA (Proof of Authority) as the consensus protocol.
    •	Develop a base Flight ticket management contract in Solidity to allow.
    •	Use MetaMask as the wallet for Customers.
    •	Demonstrate contract behavior via Remix connected to the private blockchain.
*/

pragma solidity >=0.8.16 <0.9.0;
import "hardhat/console.sol";
/*
Airport Codes - Domestic (India)
    BOM (Mumbai), DEL (Delhi), BLR (Bengaluru), MAA (Chennai), CCU (Kolkata)
Airport Codes - International 
    NYC (New York, USA), AMS (Amsterdam, Netherlands), TYO (Tokyo, Japan), SYD (Sydney, Australia)
*/

/*
The EagleTicket contract keeps track of the flight details & ticket buyer (customer) details across multiple flights.
*/
contract EagleTicket {
    // Data members
    // Airline Type - enumerates various Airline types
    enum AirlineType { DOMESTIC, INTERNATIONAL }
    // TicketStatus - enumerates various ticket states
    enum TicketStatus { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
    // FlightStatus - enumerates various flight states
    enum FlightStatus { DOES_NOT_EXIST, SCHEDULED, SCHEDULED_FULL, ON_TIME, DELAYED, IN_AIR, CANCELLED, LANDED }
    // PaymentStatus - enumerates the payment states
    enum PaymentStatus { ESCROWED, PAID_IN_FULL, PAID_IN_PART } 
    // Airline info
    struct AirlineInfo {
        address airlineAddress; // operating airline address
        AirlineType airlineType; // operating airline Type - Domestic / International
        string airlineCode; // 2-char airline Code
    }
    mapping (address => AirlineInfo) airlineMap;
    //
    struct CustomerInfo {
        address customerAddress; // customer address
        string customerName; // customer name
    }
    mapping (address => CustomerInfo) customerMap;
    // FlightInfo - contains all the Flight information
    struct FlightInfo {
        uint flightNumber; // unique identifier number
        address airline; // operating airline address
        string flightID; //
        uint plannedDatetime; // original Planned departure date & time (EPOCH timestamp Format)
        uint scheduledDatetime; // adjusted (delayed/rescheduled/actual departure) flight date & time (EPOCH timestamp Format)
        string flightOrigin; // Origin Airport Code
        string flightDestination; // Destination Airport Code
        FlightStatus flightStatus; // last known status of flight
    }
    mapping (uint => FlightInfo) private flightMap; // flightNumber => FlightInfo
    // TicketInfo - contains all the Ticket information
    struct TicketInfo {
        uint ticketNumber; // "1234567890123" unique 13-digit number
        address customer; // buyer
        uint flightNumber; // flight
        string seatCategory; // "Economy"
        string seatNumber; // "24A"
        uint ticketPrice; // buying price
        uint refundAmount; // amount refunded to Customer, if any 
        uint paidAmount; // amount paid to Airline, if any
        TicketStatus ticketStatus;
        PaymentStatus paymentStatus;
    }
    // TicketInfo[] private tickets;
    mapping (uint => TicketInfo) private ticketMap;
    //
    mapping(uint => mapping(string => uint)) private flightSeatTicketMap; // flightNumber => string seatNumber => uint ticketNumber
    //mapping(uint => string) ticketSeatMap; // uint ticketNumber => string seatNumber
    //
    uint private _lastTicketNumber;

    // CONSTRUCTOR
    constructor () {
        _lastTicketNumber = 1000000000000;
    }
    
    // MODIFIERS
    modifier OnlyAirline() {
        require(msg.sender == address(airlineMap[msg.sender].airlineAddress), "Operation not allowed! For registered Airlines Only");
        _;
    }
    //
    modifier OnlyCustomer() {
        require(msg.sender == address(customerMap[msg.sender].customerAddress), "Operation not allowed! For registered Customers Only");
        _;
    }
    
    // OTHER/COMMON Functions
    function _getTicketstatus(uint ticketNumber) private view returns (TicketStatus) {
        // { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
        if (ticketMap[ticketNumber].ticketNumber ==  ticketNumber) {
            return ticketMap[ticketNumber].ticketStatus;
        }
        return TicketStatus.DOES_NOT_EXIST;
    }
    //
    function checkFlightStatus(string memory flightNumber, uint date) public view returns (bool found, string memory) {
        // { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
        // TODO
        return (false, "Pending implementation");
    }
    //
    function refundStatus() public returns (bool success, string memory) {
        // TODO
        return (false, "Pending implementation");
    }
    //
    function checkTicketstatus(uint ticketNumber) public view returns (bool success, string memory message) {
        // { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
        TicketStatus ticketStatus = _getTicketstatus (ticketNumber);
        if (ticketStatus == TicketStatus.RESERVED) {
            success = true;
            message = "Reserved";
        } else if (ticketStatus == TicketStatus.CANCELLATION_IN_PROGRESS ) {
            success = true;
            message = "Cancellation In Progress";
        } else if (ticketStatus == TicketStatus.CANCELLED) {
            success = true;
            message = "Cancelled";
        }
        else {
            success = false;
            message = "Does Not Exist";
        }
    }
    //
    function processRefund() public returns (bool success, string memory) {
        // TODO
        return (false, "Pending implementation");
    }
    //
    function _unblockSeat(uint flightNumber, string memory seatNumber) private returns (bool success, string memory) {
        // TODO: Validations !!
        flightSeatTicketMap[flightNumber][seatNumber] = 0;
        return (true, "!INFO! Unblocked Seat.");
    }

    // CUSTOMER Functions
    // Customer Registration
    function registerCustomer (address customerAddress, string memory customerName) public returns (bool success ) {
        customerMap[customerAddress] = CustomerInfo(customerAddress, customerName);
        if (customerMap[customerAddress].customerAddress == customerAddress) {
            // Customer registered
            console.log ("Customer Registered: ", customerAddress);
            return (true);
        }
        return (false);
    }
    // !! PAYABLE !!
    function buyticket (address customer, string memory flightNumber, string memory  _seatNumber) 
        OnlyCustomer
        public payable returns (bool success, string memory) {
        // TODO
        return (false, "Pending implementation");
    }
    //
    function cancelticket (uint ticketNumber) public returns (bool success) {
        TicketStatus status = _getTicketstatus (ticketNumber);
        require(status == TicketStatus.RESERVED, "!ERROR! Ticket cannot be cancelled.");
        // Cancel Ticket
        // TODO: Perform Cancellation
        ticketMap[ticketNumber].ticketStatus = TicketStatus.CANCELLATION_IN_PROGRESS;
        return (false);
    }
    //
    function selectSeat (uint ticketNumber, string memory seatNumber) OnlyCustomer public returns (bool success, string memory message) {
        require(ticketMap[ticketNumber].ticketNumber == ticketNumber, "!ERROR! Invalid Ticket Number.");
        uint found_flightNumber = ticketMap[ticketNumber].flightNumber;
        uint found_seatTicketNumber = flightSeatTicketMap[found_flightNumber][seatNumber];
        string memory found_ticketSeatNumber = ticketMap[ticketNumber].seatNumber;
        bytes memory bLen = bytes(found_ticketSeatNumber);
        if (found_seatTicketNumber == ticketNumber) {
            message = "!INFO! Seat already assigned to Ticket.";
            success = true;
            console.log(success, message);
        } else if (found_seatTicketNumber != ticketNumber && found_seatTicketNumber != 0) {
            message = "!ERROR! Seat is assigned to another Ticket.";
            success = false;
            console.log(success, message);
        } else {
            if (
                keccak256(abi.encodePacked(found_ticketSeatNumber)) != keccak256(abi.encodePacked(seatNumber))
                &&  bLen.length > 0
            ) {
                _unblockSeat (found_flightNumber, seatNumber); // unblock previously held seat
                message = "!INFO! Seat changed for Ticket.";
            }
            else {
                 message = "!INFO! Seat assigned to Ticket.";
            }
            success = true;
            ticketMap[ticketNumber].seatNumber = seatNumber;
            flightSeatTicketMap[found_flightNumber][seatNumber] = ticketNumber;
        }
        //
        console.log(success, message);
        if (!success) {
            revert(message);
        }
    }

    function claimRefund (uint ticketNumber) public returns (bool success, string memory) {
        // TODO
        return (false, "Pending implementation");
    }

    // AIRLINE Functions
    function setupFlight (
            uint flightNumber, // unique identifier number
            string memory flightID, //
            uint plannedDatetime, // original Planned departure date & time 
            string memory flightOrigin, // Origin Airport Code
            string memory flightDestination // Destination Airport Code
        ) 
        OnlyAirline public returns (bool, string memory) {
        if (flightMap[flightNumber].flightNumber == flightNumber) {
            return (true, "!INFO! Flight already setup.");
        } else {
            FlightInfo memory flight = FlightInfo ({  
                flightNumber: flightNumber,
                airline: msg.sender,
                flightID: flightID,
                plannedDatetime: plannedDatetime,
                scheduledDatetime: plannedDatetime,
                flightOrigin: flightOrigin,
                flightDestination: flightDestination,
                flightStatus: FlightStatus.SCHEDULED
            });
            flightMap[flightNumber] = flight;
            return (true, "!INFO! Flight has been setup.");
        }
    }

    function updateFlightStatus (uint flightNumber, FlightStatus flightStatus) OnlyAirline public returns (bool success, string memory) {
        // TODO: perform status validations as needed
        flightMap[flightNumber].flightStatus = flightStatus;
        return (false, "Pending implementation");
    }
}