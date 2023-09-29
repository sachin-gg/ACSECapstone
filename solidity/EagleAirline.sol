// SPDX-License-Identifier: MIT
/*
* Batch: ACSE IITM August 2022
* Project: Problem Statement 3 - Blockchain based Ticket Management
* Developers: 
    Mohan Sami (Group Lead)
    Anuradha Kapoor
    Reema Chhetri
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

pragma solidity ^0.8.17;
// For console.log
import "hardhat/console.sol";
import "./EagleLib.sol";
/*
// To create ARMS Token
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/erc20
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
// To generate and own ARMS Tokens
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable
import "@openzeppelin/contracts/access/Ownable.sol";
*/
///////////////////////////////////////////////////////////////////////////////////////////////
// ARMS Token contract - ARMS will be the toekn used by Customers to buy Eagle Airline Tickets
/*
contract ARMSToken is ERC20 {
    address payable public owner;
    constructor() ERC20("ARMS Eagle Airline Token", "ARMS")  {
        owner = payable(msg.sender);
        _mint(owner, 100000000 * (10 ** decimals())); // default = 18 decimals
    }
}
*/
///////////////////////////////////////////////////////////////////////////////////////////////
/*
* Sample Airport Codes - Domestic (India)
    BOM (Mumbai), DEL (Delhi), BLR (Bengaluru), MAA (Chennai), CCU (Kolkata)
* Sample Airport Codes - International 
    NYC (New York, USA), AMS (Amsterdam, Netherlands), TYO (Tokyo, Japan), SYD (Sydney, Australia)
* Datetime <> Epoch Timestamp convertor
    https://www.epochconverter.com/
*/
///////////////////////////////////////////////////////////////////////////////////////////////
// Eagle Airline contract - keeps track of the Arilines & flight details & ticket buyer (customer) details across multiple flights.
contract EagleAirline {
    //
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    /// Airline Type - enumerates various Airline types
    enum AirlineType { DOMESTIC, INTERNATIONAL }
    uint8 public constant MAX_SEATING_CAPACITY = 100;
    uint public constant TICKET_PRICE_DOMESTIC = 10 ether;
    uint public constant TICKET_PRICE_INTERNATIONAL = 50 ether;
    //
    // Airline info
    struct AirlineInfo {
        address payable airlineAddress; // operating airline address
        AirlineType airlineType; // operating airline Type - Domestic / International
        string airlineName; // Name of Airline
        string airlineCode; // 2-char airline Code
    }
    mapping (address => AirlineInfo) airlineMap; // airline address => AirlineInfo
    //////////////////////////////////////////////////
    // TO BE MOVED
    // Customer Info
    struct CustomerInfo {
        address payable customerAddress; // customer address
        string customerName; // customer name
    }
    mapping (address => CustomerInfo) customerMap;
    // TicketInfo - contains all the Ticket information
    struct TicketInfo {
        uint ticketNumber; // "1234567890123" unique 13-digit number
        address customer; // buyer
        uint flightNumber; // flight
        //string seatCategory; // "Economy"
        string seatNumber; // "A24"
        uint refundAmount; // amount refunded to Customer, if any 
        uint paidAmount; // amount paid to Airline, if any
        uint8 ticketStatus; // last known status of ticket
        uint8 paymentStatus; // last known status of payment
        uint ticketStatusDatetime; // last ticket status update date time
        uint paymentStatusDatetime; // last payment status update date time
    }
    mapping (uint => TicketInfo) private ticketMap;
    //mapping(uint => string) ticketSeatMap; // uint ticketNumber => string seatNumber
    //////////////////////////////////////////////////
    // FlightInfo - contains all the Flight information
    struct FlightInfo {
        uint flightNumber; // unique identifier number
        address airline; // operating airline address
        string flightName; // e.g. EI204 / ED345
        uint schDepartureDatetime; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint schArrivalDatetime; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint actDepartureDatetime; // actual departure flight date & time (EPOCH timestamp Format)
        uint actArrivalDatetime; // original Scheduled departure date & time (EPOCH timestamp Format)
        //uint revDepartureDatetime; // revised (delayed/rescheduled) flight date & time (EPOCH timestamp Format)
        //uint revArrivalDatetime; // revised (delayed/rescheduled) flight date & time (EPOCH timestamp Format)
        uint delayMinutes;
        string flightOrigin; // Origin Airport Code
        string flightDestination; // Destination Airport Code
        uint8 flightStatus; // last known status of flight
        uint flightStatusDateTime; // last flight status update date time
        //uint8 seatingCapacity; // max number of seats // capped to 255
        uint8 remainingCapacity;
        //bool isFull;
        //bool isClosed;
        bool ticketAvailable;
        //uint16 fixedPrice; // buying price - consider a fixed ticket price for now
    }
    mapping (uint => FlightInfo) private flightMap; // flightNumber => FlightInfo
    mapping (address => address) private ticketFlightMap; // ticketAddress => flightNumber
    mapping(uint => mapping(string => address)) private flightSeatTicketMap; // flightNumber => string seatNumber => uint ticketNumber
    //
    address private _contractAddress;
    address private _superUser;
    uint private _lastTicketNumber; // Ticket number
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    constructor (address superUser) {
        require(superUser != address(0), "Error: Super User required");
        _superUser = superUser;
        _contractAddress = address(this);
        _lastTicketNumber = 1000000000000;
        //_priceDecimals = 18; // 1 eth = 10***18 wei
        emit ContractCreated ("EagleAirline", address(this));
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string contractName, address indexed contractAddress);
    event AirlineRegistered(string airlineType, string airlineName, string airlineCode);
    event FlightRegistered(uint flightNumber, string flightName);
    event FlightUpdate(uint flightNumber, string updateMessage);
    //event TicketUpdate(uint ticketNumber, address indexed ticketAddress);
    //event TicketCancelled (uint ticketNumber);
    event TransferredAmout(address indexed fromAddress, address indexed toAddress, uint amount, string message);
    //event FlightUpdate (address indexed airline, uint flightNumber, string flightName, string flightStatus, string message);
    event FlightCancelled (address indexed airline, uint flightNumber, string message); // When the flight is Cancelled
    //event TicketReserved (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, uint transferredAmount, string message);
    //event TicketCancelled (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, string message);
    event ErrorMessage(string errorMessage);
    event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    // MODIFIERS
    modifier NoAirlines() {
        require(msg.sender != address(airlineMap[msg.sender].airlineAddress), "!ERROR! Airlines not allowed.");
        _;
    }
    //
    modifier NoCustomers() {
        require(msg.sender != address(customerMap[msg.sender].customerAddress), "!ERROR! Customers not allowed.");
        _;
    }
    //
    modifier OnlyAirlines() {
        require(msg.sender == address(airlineMap[msg.sender].airlineAddress), "Operation not allowed! Only registered Airlines allowed");
        _;
    }
    //
    /*
    modifier OnlyCustomers() {
        require(msg.sender == address(customerMap[msg.sender].customerAddress), "Operation not allowed! Only registered Customers allowed");
        _;
    }
    */
    //
    modifier OnlyFlightOperator(uint flightNumber) {
        require(msg.sender != address(flightMap[flightNumber].airline), "Only Flight Operating Airline allowed");
        _;
    }
    //
    modifier OnlyTicketSeller(uint ticketNumber) {
        require(msg.sender == address(flightMap[ticketMap[ticketNumber].flightNumber].airline), "Operation not allowed! Only Airline Operator allowed");
        _;
    }
    //
    modifier OnlyTicketBuyer(uint ticketNumber) {
        require(msg.sender == address(ticketMap[ticketNumber].customer), "Operation not allowed! Only Ticket Buyer allowed");
        _;
    }
    //
    modifier OnlyTicketBuyerOrSeller(uint ticketNumber) {
        require(
                (
                    msg.sender == address(flightMap[ticketMap[ticketNumber].flightNumber].airline)
                    || msg.sender == address(ticketMap[ticketNumber].customer)
                ),
                "Operation not allowed! Only Airline Operator / Ticket Buyer allowed"
            );
        _;
    }
    //
    modifier CheckTicketNumber(uint ticketNumber) {
        // Valid ticket numbers are 13 digits
        require(ticketNumber > 1000000000000 && ticketNumber < 10000000000000, "Invalid Ticket Number provided");
        _;
    }
    //
    modifier OnlyValidTicketNumbers(uint ticketNumber) {
        require(ticketMap[ticketNumber].ticketNumber == ticketNumber, "Invalid Ticket Number");
        _;
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // OTHER/COMMON Functions
    /*
    // Helper function to get ticket object
    function _getTicket(uint ticketNumber) private view returns (TicketInfo memory ticket) {
        return ticketMap[ticketNumber];
    }
    */
    // Helper function to get flight object
    function _getFlight(uint flightNumber) private view returns (FlightInfo memory flight) {
        return flightMap[flightNumber];
    }
    /*
    // Helper function to get ticket status message
    function _getTicketStatusMessage (uint status) private pure returns (string memory) {
        if (status == EagleLib.Ticket_DOES_NOT_EXIST) {
            return "Invalid Ticket";
        } else if (status == EagleLib.Ticket_RESERVED) {
            return "Ticket is Reserved";
        } else if (status == EagleLib.Ticket_CANCELLATION_IN_PROGRESS) {
            return "Ticket cancellation is in progress";
        } else if (status == EagleLib.Ticket_CANCELLED) {
            return "Ticket has been cancelled";
        } else {
            return "Unknown Flight Status";
        }
    }
    //
    // Helper function to get ticket status
    function _getTicketStatus (uint ticketNumber) private view returns (uint8) {
        if (_getTicket(ticketNumber).ticketNumber ==  ticketNumber) {
            return ticketMap[ticketNumber].ticketStatus;
        }
        return EagleLib.Ticket_DOES_NOT_EXIST;
    }
    */
    // Helper function to check flight status
    function checkFlightStatus(uint flightNumber) public view returns (string memory statusMessage) {
        require (flightNumber == flightMap[flightNumber].flightNumber, "Unknown Flight");
        uint8 status = flightMap[flightNumber].flightStatus;
        bool ticketAvailable = flightMap[flightNumber].ticketAvailable;
        uint8 remainingCapacity = flightMap[flightNumber].remainingCapacity;
        string memory availability = (
            (ticketAvailable && remainingCapacity > 0)
            ? string.concat(" (Avl: ", EagleLib.uintToString(flightMap[flightNumber].remainingCapacity), ")")
            : " (Avl: 0)"
        );
        if (status == EagleLib.Flight_SCHEDULED) {
            statusMessage = string.concat("SCHEDULED", availability);
        } else if (status == EagleLib.Flight_ON_TIME) {
            statusMessage = string.concat("ON-TIME", availability);
        } else if (status == EagleLib.Flight_DELAYED) {
            statusMessage = string.concat("DELAYED", availability);
        } else if (status == EagleLib.Flight_BOARDING) {
            statusMessage = string.concat("BOARDING", availability);
        } else if (status == EagleLib.Flight_IN_AIR) {
            statusMessage = "IN-AIR";
        } else if (status == EagleLib.Flight_CANCELLED) {
            statusMessage = "CANCELLED";
        } else if (status == EagleLib.Flight_LANDED) {
            statusMessage = "LANDED";
        } else {
            statusMessage = "Unknown Flight Status";
            revert(statusMessage);
        }
    }

    // Helper function to Unblock seat number after cancellation
    function _unblockSeat(uint flightNumber, string memory seatNumber) private returns (bool success) {
        delete(flightSeatTicketMap[flightNumber][seatNumber]);
        success = true;
        console.log("Unblocked Seat");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // AIRLINE/SELLER OR CUSTOMER/BUYER Functions
    /*
    * refundStatus - Allows Buyers & Sellers to check their refund status
    */
    function refundStatus(uint ticketNumber) OnlyTicketBuyerOrSeller(ticketNumber) public view returns (bool success) {
        success = false;
        string memory message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }


    /*
    * checkTicketstatus - Allows Buyers & Sellers to check their ticket status
    */
    function checkTicketstatus(uint ticketNumber) OnlyTicketBuyerOrSeller(ticketNumber) public view returns (bool success) {
        success = false;
        string memory message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    } 

    /*
    * processRefund - Allows Sellers to process refund claims
    */
    // !! PAYABLE !!
    function processRefund(uint ticketNumber) OnlyTicketSeller(ticketNumber) public view returns (bool success) {
        success = false;
        string memory message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }

   
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // AIRLINE Functions
    /*
    * _registerAirline - Airline registration helper function
    */
    function _registerAirline (string memory airlineName, string memory airlineCode, AirlineType airlineType) private returns  (bool success) {
        AirlineInfo memory airline = AirlineInfo({
            airlineAddress: payable(msg.sender),
            airlineType: airlineType,
            airlineName: airlineName,
            airlineCode: airlineCode});
        if (airlineMap[airline.airlineAddress].airlineAddress == airline.airlineAddress) {
            success = true;
            revert (string.concat("Airline already setup - ", airlineMap[airline.airlineAddress].airlineName));
        } else {
            // We've a new Airline; add it to the map
            airlineMap[airline.airlineAddress] = airline;
            return true;
        }
    }

    /*
    * registerDomesticAirline - Allows Airline to register a DOMESTIC operator
    */
    function registerDomesticAirline (string memory airlineName, string memory airlineCode) NoCustomers public returns (bool success) {
        require(msg.sender != address(0), "Invalid Airline address");
        success = _registerAirline(airlineName, airlineCode, AirlineType.DOMESTIC);
        require(success, "Failed to Register Airline");
        emit AirlineRegistered("DOMESTIC", airlineName, airlineCode);
    }

    /*
    * registerInternationalAirline - Allows Airline to register a INTERNATIONAL operator
    */
    function registerInternationalAirline (string memory airlineName, string memory airlineCode) NoCustomers public returns (bool success) {
        require(msg.sender != address(0), "Invalid Airline address");
        success = _registerAirline(airlineName, airlineCode, AirlineType.INTERNATIONAL);
        require(success, "Failed to Register Airline");
        emit AirlineRegistered("INTERNATIONAL", airlineName, airlineCode);
    }

    /*
    * registerInternationalAirline - Allows resgiter Airline operators to setup flight info
    */
    function setupFlight (
            uint flightNumber, // unique identifier number
            string memory flightName, //
            uint schDepartureDatetime, // original Scheduled departure date & time
            uint schArrivalDatetime, // original Scheduled arrival date & time
            string memory flightOrigin, // Origin Airport Code
            string memory flightDestination // Destination Airport Code
            //uint seatingCapacity,
            //uint fixedPrice
        ) 
        OnlyAirlines public returns (bool success) {
        if (flightMap[flightNumber].flightNumber == flightNumber) {
            success = true;
            revert("Flight already setup");
        } else {
            FlightInfo memory flight = FlightInfo ({  
                flightNumber: flightNumber,
                airline: msg.sender,
                flightName: flightName,
                schDepartureDatetime: schDepartureDatetime,
                schArrivalDatetime: schArrivalDatetime,
                actDepartureDatetime: 0,
                actArrivalDatetime: 0,
                //revDepartureDatetime: schDepartureDatetime,
                //revArrivalDatetime: schArrivalDatetime,
                delayMinutes: 0,
                flightOrigin: flightOrigin,
                flightDestination: flightDestination,
                flightStatus: EagleLib.Flight_SCHEDULED,
                flightStatusDateTime: block.timestamp,
                //seatingCapacity: seatingCapacity,
                remainingCapacity: MAX_SEATING_CAPACITY,
                ticketAvailable: true
                //isFull: false,
                //isClosed: true
                //fixedPrice: fixedPrice
            });
            flightMap[flightNumber] = flight;
            success = true;
            emit FlightRegistered(flightNumber, flightName);
        }
    }


    /*
    * FLIGHT STATUS UPDATE functions - Allows Airline operator to update Flight status 
    */
    function flightSOLDOUT (uint flightNumber) OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        require (
            flightMap[flightNumber].flightStatus >= EagleLib.Flight_SCHEDULED 
            && flightMap[flightNumber].flightStatus <= EagleLib.Flight_BOARDING,
            "Flight cannot be updated."
        );
        flightMap[flightNumber].ticketAvailable = false;
        flightMap[flightNumber].flightStatusDateTime = block.timestamp;
        success = true;
        emit FlightUpdate(flightNumber, "Floght is SOLDOUT");
    }

    function _updateFlightStatus (uint flightNumber, uint8 flightStatus, uint delayMinutes) private returns (bool success) {
        flightMap[flightNumber].flightStatus = flightStatus;
        flightMap[flightNumber].delayMinutes = delayMinutes;
        flightMap[flightNumber].flightStatusDateTime = block.timestamp;
        return true;
    }

    function flightONTIME (uint flightNumber)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_ON_TIME, 0);
        success = true;
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, "Flight is ON-TIME");
    }

    function flightDELAYED (uint flightNumber, uint delayMinutesFromSchTime)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        require(delayMinutesFromSchTime > 0, "Invalid delay time");
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_ON_TIME, delayMinutesFromSchTime);
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, string.concat("Flight delayed by ", EagleLib.uintToString (delayMinutesFromSchTime)));
    }

    function flightBOARDING (uint flightNumber)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        flightMap[flightNumber].ticketAvailable = false;
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_BOARDING, 0);
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, "Flight is BOARDING");
    }

    function flightINAIR (uint flightNumber)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        flightMap[flightNumber].actDepartureDatetime = block.timestamp;
        flightMap[flightNumber].delayMinutes = EagleLib.getTSTimeDiff(flightMap[flightNumber].schDepartureDatetime, block.timestamp, EagleLib.DatePart.MINUTES);
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_IN_AIR, 0);
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, "Flight is IN-AIR");
    }

    function flightCANCELLED (uint flightNumber)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        require (
            flightMap[flightNumber].flightStatus >= EagleLib.Flight_SCHEDULED 
            && flightMap[flightNumber].flightStatus <= EagleLib.Flight_BOARDING,
            "Flight Cannot be cancelled"
        );
        flightMap[flightNumber].actDepartureDatetime = 0;
        flightMap[flightNumber].actArrivalDatetime = 0;
        flightMap[flightNumber].ticketAvailable = false;
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_CANCELLED, 0);
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, "Flight is CANCELLED");
    }

    function flightLANDED (uint flightNumber)
        OnlyFlightOperator(flightNumber) 
        public returns (bool success) {
        require (flightMap[flightNumber].flightStatus == EagleLib.Flight_IN_AIR, "Flight cannot be updated.");
        flightMap[flightNumber].actArrivalDatetime = block.timestamp;
        flightMap[flightNumber].ticketAvailable = false;
        success = _updateFlightStatus(flightNumber, EagleLib.Flight_LANDED, 0);
        require(success, "Failed to update status");
        emit FlightUpdate(flightNumber, "Flight has LANDED");
    }
}