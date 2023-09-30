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
import "./EagleTicket.sol";

// Eagle Airline contract - keeps track of the Arilines & flight details & ticket buyer (customer) details across multiple flights.
contract EagleAirline {
    //
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    /// Airline Type - enumerates various Airline types
    enum OperatorType { DOMESTIC, INTERNATIONAL }
    uint8 public constant MAX_SEATING_CAPACITY = 100;
    uint public constant TICKET_PRICE_DOMESTIC = 10 ether;
    uint public constant TICKET_PRICE_INTERNATIONAL = 50 ether;
    // FlightStatus - enumerates various flight states
    //enum FlightStatus { DOES_NOT_EXIST, SCHEDULED, ON_TIME, DELAYED, BOARDING, IN_AIR, CANCELLED, LANDED }
    uint8 private constant FLIGHT_DOES_NOT_EXIST = 0;
    uint8 private constant FLIGHT_SCHEDULED = 1;
    uint8 private constant FLIGHT_ON_TIME = 2;
    uint8 private constant FLIGHT_DELAYED = 3;
    uint8 private constant FLIGHT_BOARDING = 4;
    uint8 private constant FLIGHT_IN_AIR = 5;
    uint8 private constant FLIGHT_CANCELLED = 6;
    uint8 private constant FLIGHT_LANDED = 7;
    // Airline Operator info
    struct OperatorInfo {
        address payable operatorAddress; // operating airline address
        OperatorType operatorType; // operating airline Type - Domestic / International
        string operatorName; // Name of Airline
        string operatorCode; // 2-char airline Code
        bool active;
    }
    mapping(address => OperatorInfo) operatorMap; // airline address => OperatorInfo
    //////////////////////////////////////////////////
    // TO BE MOVED
    // Customer Info
    struct CustomerInfo {
        address payable customerAddress; // customer address
        string customerName; // customer name
        bool active;
    }
    mapping(address => CustomerInfo) customerMap;
     //////////////////////////////////////////////////
    // FlightInfo - contains all the Flight information
    struct FlightInfo {
        uint flightNumber; // unique identifier number
        address operatorAddress; // operating airline address
        string flightName; // e.g. EI204 / ED345
        uint schDepartureTimeStamp; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint schArrivalTimeStamp; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint actDepartureTimeStamp; // actual departure flight date & time (EPOCH timestamp Format)
        uint actArrivalTimeStamp; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint delayMinutes;
        string flightOrigin; // Origin Airport Code
        string flightDestination; // Destination Airport Code
        uint8 flightStatus; // last known status of flight
        uint flightStatusTimeStamp; // last flight status update date time
        uint8 remainingCapacity;
        bool ticketAvailable;
        bool active;
        address[] allTickets; // open Ticket Contracts
    }
    mapping(uint => FlightInfo) private flightMap; // flightNumber => FlightInfo
    // TicketInfo - contains all the Ticket information
    struct TicketInfo {
        //uint secretKey;
        address ticketContract;
        uint ticketNumber; // "1234567890123" unique 13-digit number
        address buyer; // buyer
        uint flightNumber; // flight
        //string seatCategory; // "Economy"
        string seatNumber; // "A24"
        uint ticketAmount;
        bool active;
    }
    mapping(address => TicketInfo) private pendingTicketMap; // ticketAddress => pending TicketInfo
    mapping(address => TicketInfo) private confirmedTicketMap; // ticketAddress => confirmed TicketInfo
    //mapping(address => TicketInfo) private cancelledTicketMap; // ticketAddress => cancelled TicketInfo
    mapping(address => TicketInfo) private closedTicketMap; // ticketAddress => closed TicketInfo
    mapping(uint => mapping(string => address)) private flightSeatTicketMap; // flightNumber => string seatNumber => uint ticketContract
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
        //_lastFlightNumber = 1000; // Ticket number
        //_priceDecimals = 18; // 1 eth = 10***18 wei
        emit ContractCreated ("EagleAirline", address(this));
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string contractName, address indexed contractAddress);
    event OperatorRegistered(string operatorType, string operatorName, string operatorCode);
    event FlightRegistered(uint flightNumber, string flightName);
    event FlightUpdate(uint flightNumber, string updateMessage);
    event TicketReserved(uint ticketNumber, address indexed ticketAddress);
    //event ErrorMessage(string errorMessage);
    //event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    modifier noAirlines() {
        require(msg.sender != address(operatorMap[msg.sender].operatorAddress), "!ERROR! Airlines not allowed.");
        _;
    }
    //
    modifier noCustomers() {
        require(msg.sender != address(customerMap[msg.sender].customerAddress), "!ERROR! Customers not allowed.");
        _;
    }
    //
    modifier onlyAirlines() {
        require(msg.sender == address(operatorMap[msg.sender].operatorAddress), "Operation not allowed! Only registered Airlines allowed");
        _;
    }
    //
    modifier onlyCustomers() {
        require(msg.sender == address(customerMap[msg.sender].customerAddress), "Operation not allowed! Only registered Customers allowed");
        _;
    }
    //
    modifier onlyFlightOperator(uint flightNumber) {
        require(msg.sender == address(flightMap[flightNumber].operatorAddress), "Only Flight Operator allowed");
        _;
    }
    /*
    modifier onlyTicketSeller(address ticketContract) {
        require(msg.sender == address(flightMap[ticketContractMap[ticketContract].flightNumber].operatorAddress), "Only Flight Operator allowed");
        _;
    }
    */
    modifier onlyConfirmedTicketContracts() {
        require(confirmedTicketMap[msg.sender].active, "Only Confirmed Tickets allowed");
        _;
    }
    //
    modifier onlyPendingTicketContracts() {
        require(pendingTicketMap[msg.sender].active, "Only Confirmed Tickets allowed");
        _;
    }
    /*
    modifier OnlyConfirmedTicketBuyerOrSeller(address ticketContract) {
        require((
            confirmedTicketMap[msg.sender].active
            || flightMap[ticketContractMap[ticketContract].flightNumber].active),
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
    modifier OnlyValidTicketContracts(address ticketContract) {
        require(ticketContractMap[msg.sender].active, "Invalid Ticket");
        _;
    }
    */
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // OTHER/COMMON Functions
    /*
    // Helper function to get flight object
    function _getFlight(uint flightNumber) private view returns (FlightInfo memory flight) {
        return flightMap[flightNumber];
    }
    */

    function getFlightStatus(uint flightNumber) public view returns (uint8) {
        require (flightNumber == flightMap[flightNumber].flightNumber, "Unknown Flight");
        return flightMap[flightNumber].flightStatus;
    }

    // check flight status
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
        if (status == FLIGHT_SCHEDULED) {
            statusMessage = string.concat("SCHEDULED", availability);
        } else if (status == FLIGHT_ON_TIME) {
            statusMessage = string.concat("ON-TIME", availability);
        } else if (status == FLIGHT_DELAYED) {
            statusMessage = string.concat("DELAYED", availability);
        } else if (status == FLIGHT_BOARDING) {
            statusMessage = string.concat("BOARDING", availability);
        } else if (status == FLIGHT_IN_AIR) {
            statusMessage = "IN-AIR";
        } else if (status == FLIGHT_CANCELLED) {
            statusMessage = "CANCELLED";
        } else if (status == FLIGHT_LANDED) {
            statusMessage = "LANDED";
        } else {
            statusMessage = "Unknown Flight Status";
            revert(statusMessage);
        }
    }

    // Helper function to Unblock seat number after cancellation
    function _unblockSeat(uint flightNumber, string memory seatNumber) private returns (bool success) {
        delete(flightSeatTicketMap[flightNumber][seatNumber]);
        success = (flightSeatTicketMap[flightNumber][seatNumber] == address(0) ? true : false);
    }

      ///////////////////////////////////////////////////////////////////////////////////////////////
    // AIRLINE Functions
    /*
    * _registerAirlineOperator - Airline Operator registration helper function
    */
    function _registerAirlineOperator (string memory operatorName, string memory operatorCode, OperatorType operatorType) private returns  (bool success) {
        OperatorInfo memory operator = OperatorInfo({
            operatorAddress: payable(msg.sender),
            operatorType: operatorType,
            operatorName: operatorName,
            operatorCode: operatorCode,
            active: true
        });
        if (operatorMap[operator.operatorAddress].active) {
            success = true;
            revert (string.concat("REV: Existing - ", operatorMap[operator.operatorAddress].operatorName));
        } else {
            // We've a new Operator; add it to the map
            operatorMap[operator.operatorAddress] = operator;
            return true;
        }
    }

    /*
    * registerDomesticOperator - Allows Airline register a DOMESTIC operator
    */
    function registerDomesticOperator (string memory operatorName, string memory operatorCode) noCustomers public returns (bool success) {
        success = _registerAirlineOperator(operatorName, operatorCode, OperatorType.DOMESTIC);
        require(success, "ERR: Not Reg.");
        emit OperatorRegistered("DOMESTIC", operatorName, operatorCode);
    }

    /*
    * registerInternationalOperator - Allows Airline to register a INTERNATIONAL operator
    */
    function registerInternationalOperator (string memory operatorName, string memory operatorCode) noCustomers public returns (bool success) {
        success = _registerAirlineOperator(operatorName, operatorCode, OperatorType.INTERNATIONAL);
        require(success, "Failed to Register Airline Operator");
        emit OperatorRegistered("INTERNATIONAL", operatorName, operatorCode);
    }

    /*
    * setupFlight - Allows Airline operators to setup flight info
    */
    function setupFlight (
            uint flightNumber, // unique identifier number
            string memory flightName, //
            uint schDepartureTimeStamp, // original Scheduled departure date & time
            uint schArrivalTimeStamp, // original Scheduled arrival date & time
            string memory flightOrigin, // Origin Airport Code
            string memory flightDestination // Destination Airport Code
            //uint seatingCapacity,
            //uint fixedPrice
        ) 
        onlyAirlines public returns (bool success) {
        if (flightMap[flightNumber].active) {
            success = true;
            revert("Flight already setup");
        } else {
            FlightInfo storage flight = flightMap[flightNumber];
            flight.flightNumber = flightNumber;
            flight.operatorAddress = msg.sender;
            flight.flightName = flightName;
            flight.schDepartureTimeStamp = schDepartureTimeStamp;
            flight.schArrivalTimeStamp = schArrivalTimeStamp;
            flight.actDepartureTimeStamp = 0;
            flight.actArrivalTimeStamp = 0;
            flight.delayMinutes = 0;
            flight.flightOrigin = flightOrigin;
            flight.flightDestination = flightDestination;
            flight.flightStatus = FLIGHT_SCHEDULED;
            flight.flightStatusTimeStamp = block.timestamp;
            flight.remainingCapacity = MAX_SEATING_CAPACITY;
            flight.ticketAvailable = true;
            flight.active = true;
            /*({  
                flightNumber: flightNumber,
                operatorAddress: msg.sender,
                flightName: flightName,
                schDepartureTimeStamp: schDepartureTimeStamp,
                schArrivalTimeStamp: schArrivalTimeStamp,
                actDepartureTimeStamp: 0,
                actArrivalTimeStamp: 0,
                delayMinutes: 0,
                flightOrigin: flightOrigin,
                flightDestination: flightDestination,
                flightStatus: FLIGHT_SCHEDULED,
                flightStatusTimeStamp: block.timestamp,
                remainingCapacity: MAX_SEATING_CAPACITY,
                ticketAvailable: true,
                active: true
            });*/
            flightMap[flightNumber] = flight;
            success = true;
            emit FlightRegistered(flightNumber, flightName);
        }
    }


    /*
    * FLIGHT STATUS UPDATE functions - Allows Airline operator to update Flight status 
    */
    function _updateFlightStatus (uint flightNumber, string memory stsTxt, uint8 flightStatus, uint delayMinutes) private returns (bool success) {
        flightMap[flightNumber].flightStatus = flightStatus;
        flightMap[flightNumber].delayMinutes = delayMinutes;
        flightMap[flightNumber].flightStatusTimeStamp = block.timestamp;
        success = _closeFlight(flightNumber, flightStatus);
        emit FlightUpdate(flightNumber, stsTxt);
    }

    function flightSOLDOUT (uint flightNumber) onlyFlightOperator(flightNumber) 
        public returns (bool success) {
        require (
            flightMap[flightNumber].flightStatus >= FLIGHT_SCHEDULED 
            && flightMap[flightNumber].flightStatus <= FLIGHT_BOARDING,
            "ERR: NOT UPDATETABLE"
        );
        flightMap[flightNumber].ticketAvailable = false;
        flightMap[flightNumber].flightStatusTimeStamp = block.timestamp;
        success = true;
        emit FlightUpdate(flightNumber, "SOLDOUT");
    }

    function flightONTIME (uint flightNumber) onlyFlightOperator(flightNumber)  public returns (bool) {
        return _updateFlightStatus(flightNumber, "ON-TIME", FLIGHT_ON_TIME, 0);
    }

    function flightDELAYED (uint flightNumber, uint delayMinutesFromSchTime) onlyFlightOperator(flightNumber)  public returns (bool) {
        require(delayMinutesFromSchTime > 0, "ERR: Inv delay time");
        return _updateFlightStatus(flightNumber, string.concat("DELAYED (min): ", EagleLib.uintToString (delayMinutesFromSchTime)), FLIGHT_ON_TIME, delayMinutesFromSchTime);
    }

    function flightBOARDING (uint flightNumber) onlyFlightOperator(flightNumber) public returns (bool) {
        flightMap[flightNumber].ticketAvailable = false;
        return _updateFlightStatus(flightNumber, "BOARDING", FLIGHT_BOARDING, 0);
    }

    function flightINAIR (uint flightNumber) onlyFlightOperator(flightNumber) public returns (bool) {
        flightMap[flightNumber].actDepartureTimeStamp = block.timestamp;
        flightMap[flightNumber].delayMinutes = EagleLib.getTSTimeDiff(flightMap[flightNumber].schDepartureTimeStamp, block.timestamp, EagleLib.DatePart.MINUTES);
        return _updateFlightStatus(flightNumber, "IN-AIR", FLIGHT_IN_AIR, 0);
    }

    function flightCANCELLED (uint flightNumber) onlyFlightOperator(flightNumber) public returns (bool) {
        require (
            flightMap[flightNumber].flightStatus >= FLIGHT_SCHEDULED 
            && flightMap[flightNumber].flightStatus <= FLIGHT_BOARDING,
            "ERR: NOT XLLBLE"
        );
        flightMap[flightNumber].actDepartureTimeStamp = 0;
        flightMap[flightNumber].actArrivalTimeStamp = 0;
        flightMap[flightNumber].ticketAvailable = false;
        return _updateFlightStatus(flightNumber, "CANCELLED", FLIGHT_CANCELLED, 0);
    }

    function flightLANDED (uint flightNumber) onlyFlightOperator(flightNumber) public returns (bool) {
        require (flightMap[flightNumber].flightStatus == FLIGHT_IN_AIR, "ERR: NOT UPDATETABLE");
        flightMap[flightNumber].actArrivalTimeStamp = block.timestamp;
        flightMap[flightNumber].ticketAvailable = false;
        return _updateFlightStatus(flightNumber, "LANDED", FLIGHT_LANDED, 0);
    }

    /*
    * reserveTicket - Allows customers/agents to reserve a ticket
    */
    // TODO: check modifier
    function reserveTicket(uint flightNumber, address buyerAddress)  external returns (uint, address) {
        require(flightMap[flightNumber].active, "ERR: Inv Flight");
        require(customerMap[buyerAddress].active, "ERR: Inv Customer");
        FlightInfo storage flightInfo = flightMap[flightNumber];
        require(flightInfo.ticketAvailable && flightInfo.remainingCapacity > 0, "ERR: NO SEATS AVL");
        // Create Ticket
        TicketInfo memory ticket = TicketInfo({
            ticketContract: address(0),
            ticketNumber: ++_lastTicketNumber,
            buyer: address(buyerAddress),
            flightNumber: flightNumber,
            seatNumber: "NA",
            ticketAmount: (operatorMap[flightInfo.operatorAddress].operatorType == OperatorType.DOMESTIC) ? TICKET_PRICE_DOMESTIC : TICKET_PRICE_INTERNATIONAL,
            active: true
        });
        // Create Ticket Contract
        EagleTicket ticketContract = new EagleTicket(
            _superUser,
            flightMap[flightNumber].operatorAddress,
            ticket.buyer,
            ticket.ticketNumber,
            ticket.flightNumber,
            ticket.seatNumber,
            ticket.ticketAmount,
            flightMap[flightNumber].schDepartureTimeStamp
         );
        ticket.ticketContract = address(ticketContract);
        pendingTicketMap[ticket.ticketContract] = ticket;
        flightInfo.remainingCapacity -= 1;
        flightInfo.allTickets.push(address(ticketContract));
        //address[] storage openTC = flightInfo.openTickets;
        //openTC.push(address(ticketContract));
        //
        emit TicketReserved(ticket.ticketNumber, ticket.ticketContract);
        return (ticket.ticketNumber, ticket.ticketContract);
    }

    /*
    * Confirm Ticket: Allows buyers to pay and confirm the ticket via the EagleTicket contract instance
    */
    function confirmTicket(address ticketContract) onlyPendingTicketContracts public returns (bool success) {
        TicketInfo memory pendingTicket = pendingTicketMap[ticketContract];
        uint flightNumber = pendingTicket.flightNumber;
        require(flightNumber > 0, "ERR: Inv Ticket");
        CustomerInfo memory customer = customerMap[address(msg.sender)];
        require(customer.active, "ERR: Inv Customer");
        // decrement seating capacity
        require(flightMap[flightNumber].remainingCapacity > 0, "ERR: No seats avl");
        flightMap[flightNumber].remainingCapacity--;       
        // move ticket to confirmed list
        /*
        TicketInfo memory confirmedTicket = TicketInfo({
            ticketContract: pendingTicket.ticketContract,
            ticketNumber: pendingTicket.ticketNumber,
            buyer: pendingTicket.buyer,
            flightNumber: pendingTicket.flightNumber,
            seatNumber: pendingTicket.seatNumber,
            ticketAmount: pendingTicket.ticketAmount,
            active: true
        });
        */
        TicketInfo memory confirmedTicket = pendingTicket;
        delete(pendingTicketMap[ticketContract]);
        confirmedTicketMap[ticketContract] = confirmedTicket;
        return true;
    }

    /*
    * Void Ticket: Allows buyers to cancel reserved tickets
    */
    function voidTicket(address ticketContract) onlyPendingTicketContracts public returns (bool, string memory) {
        // delete reserved ticket
        TicketInfo memory pendingTicket = pendingTicketMap[ticketContract];
        delete(pendingTicketMap[ticketContract]);
        closedTicketMap[ticketContract] = pendingTicket;
        return (true, "INFO: Reserved Ticket voided");
    }

    /*
    * Cancel Ticket: Allows buyers to cancel confirmed tickets
    */
    function cancelTicket(address ticketContract) onlyConfirmedTicketContracts public returns (bool, string memory) {
        TicketInfo memory confirmedTicket = confirmedTicketMap[ticketContract];
        uint flightNumber = confirmedTicket.flightNumber;
        require(flightNumber > 0, "ERR: Inv Ticket");
        // unblock seat
        _unblockSeat (flightNumber, confirmedTicket.seatNumber); // unblock previously held seat
        flightMap[flightNumber].remainingCapacity++;
        // move ticket to cancelled list
        TicketInfo memory cancelledTicket = confirmedTicketMap[ticketContract];
        delete(confirmedTicketMap[ticketContract]);
        closedTicketMap[ticketContract] = cancelledTicket;
        return (true, "INFO: Confirmed Ticket cancelled");
    }

    function selectSeat (address ticketContract, string memory seatNumber) onlyConfirmedTicketContracts() public returns (bool success) {
        //require(ticketMap[ticketNumber].ticketNumber == ticketNumber, "!ERROR! Invalid Ticket Number.");
        TicketInfo storage ticket = confirmedTicketMap[ticketContract];
        //uint f_flightNumber = confirmedTicketMap[ticketContract].flightNumber;
        address f_seatTicketContract = flightSeatTicketMap[ticket.flightNumber][seatNumber];
        string memory f_ticketSeatNumber = (EagleLib.stringCompare(ticket.seatNumber, "NA")) ?  "" : ticket.seatNumber;
        if (f_seatTicketContract == ticketContract) {
            success = true;
            revert("INFO: No change");
        } else if (f_seatTicketContract != ticketContract && f_seatTicketContract != address(0)) {
            success = false;
            revert("ERR: Seat blocked");
        } else {
            if (!EagleLib.stringCompare(f_ticketSeatNumber, seatNumber)) {
                _unblockSeat (ticket.flightNumber, f_ticketSeatNumber); // unblock previously held seat
            }
            success = true;
            confirmedTicketMap[ticketContract].seatNumber = seatNumber;
            flightSeatTicketMap[ticket.flightNumber][seatNumber] = ticketContract;
        }
        //require(success, "ERR: Seat assignment failed");
    }

    function _closeFlight(uint flightNumber, uint8 flightStatus) onlyFlightOperator(flightNumber) private returns (bool success) {
        require(flightStatus == FLIGHT_CANCELLED || flightStatus == FLIGHT_LANDED, "ERR: Invalid Flight Status");
        address[] memory allTickets = flightMap[flightNumber].allTickets;
        for(uint i = 0; i < allTickets.length; i++) {
            TicketInfo memory ticket;
            if (confirmedTicketMap[allTickets[i]].active) {
                ticket = confirmedTicketMap[allTickets[i]];
                delete(confirmedTicketMap[allTickets[i]]);
            } else {
                ticket = pendingTicketMap[allTickets[i]];
                delete(pendingTicketMap[allTickets[i]]);
            }
            closedTicketMap[allTickets[i]] = ticket;             
            success = EagleTicket(ticket.ticketContract).closeTicket(flightStatus);
        }
    }
}