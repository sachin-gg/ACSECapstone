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
///////////////////////////////////////////////////////////////////////////////////////////////
// Ticket Factory
contract EagleFactory {
    function createTicket(
        //address tokenARMS,
        address eagleAir,
        address opAddress,
        address buyer,
        uint ticketNum,
        uint flightNum,
        string memory seatNum,
        uint ticketAmount,
        uint schDepTS
    ) public returns (EagleTicket ticketContract) {
        return new EagleTicket(
            //tokenARMS,
            eagleAir,
            opAddress,
            buyer,
            ticketNum,
            flightNum,
            seatNum,
            ticketAmount,
            schDepTS
        );
    }
}

// Eagle Airline contract - keeps track of the Arilines & flight details & ticket buyer (customer) details across multiple flights.
contract EagleAirline {
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    /// Airline Type - enumerates various Airline types
    enum OpType { DOM, INT } // DOMESTIC, INTERNATIONAL
    uint8 public constant MAX_SEATS = 100;
    uint public constant T_PRICE_DOM = 10 * 1e18; // * 10 ** 18; // ether;
    uint public constant T_PRICE_INT = 50 * 1e18; // * 10 ** 18; //ether;
    
    // flightSts - enumerates various flight states
    //enum flightSts { DOES_NOT_EXIST, SCHEDULED, ON_TIME, DELAYED, BOARDING, IN_AIR, CANCELLED, LANDED }
    uint8 private constant FL_SCH = 0;
    uint8 private constant FL_ONTIME = 1;
    uint8 private constant FL_DLYD = 2;
    uint8 private constant FL_BRDG = 3;
    uint8 private constant FL_AIR = 4;
    uint8 private constant FL_LAND = 5;
    uint8 private constant FL_CNCL = 6;
    uint8 private constant FL_UNK = 7;
    // Airline Operator info
    struct OperatorInfo {
        address payable opAddress; // operating airline address
        OpType opType; // operating airline Type - Domestic / International
        string opName; // Name of Airline
        string opCode; // 2-char airline Code
        bool active;
    }
    mapping(address => OperatorInfo) operatorMap; // airline address => OperatorInfo
    //////////////////////////////////////////////////
    // Customer Info
    struct CustomerInfo {
        address payable custAddress; // customer address
        string custName; // customer name
        bool active;
    }
    mapping(address => CustomerInfo) customerMap;
     //////////////////////////////////////////////////
    // FlightInfo - contains all the Flight information
    struct FlightInfo {
        uint flightNum; // unique identifier number
        address opAddress; // operating airline address
        string flightName; // e.g. EI204 / ED345
        uint schDepTS; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint schArrTS; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint actDepTS; // actual departure flight date & time (EPOCH timestamp Format)
        uint actArrTS; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint delayMinutes;
        string origin; // Origin Airport Code
        string destination; // Destination Airport Code
        uint8 flightSts; // last known status of flight
        uint flightStsTS; // last flight status update date time
        uint8 remSeats;
        bool tixAvl;
        bool active;
        address[] allTickets; // open Ticket Contracts
    }
    mapping(uint => FlightInfo) private flightMap; // flightNum => FlightInfo
    // TicketInfo - contains all the Ticket information
    struct TicketInfo {
        //uint secretKey;
        address ticketContract;
        uint ticketNum; // "1234567890123" unique 13-digit number
        address buyer; // buyer
        uint flightNum; // flight
        //string seatCategory; // "Economy"
        string seatNum; // "A24"
        uint ticketAmount;
        //bool pending;
        //bool confirmed;
        //bool closed;
        bool active;
    }
    mapping(address => TicketInfo) private reservedTickMap; // ticketAddress => pending TicketInfo
    mapping(address => TicketInfo) private confirmedTickMap; // ticketAddress => confirmed TicketInfo
    mapping(address => TicketInfo) private cancelledTicketMap; // ticketAddress => cancelled TicketInfo
    mapping(address => TicketInfo) private closedTickMap; // ticketAddress => closed TicketInfo
    mapping(uint => mapping(string => address)) private flightSeatTickMap; // flightNum => string seatNum => uint ticketContract
    //
    address private _owner;
    //address private _tokenARMS;
    address private _contractAddress;
    uint private _tickCntr; // Ticket number
    EagleFactory private _factory;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    //constructor (address tokenARMS, address factory) {
    constructor (address factory) {
        _contractAddress = address(this);
        _tickCntr = 1000000000000;
        _factory = EagleFactory(factory);
        emit ContractCreated ("EagleAirline", address(this));
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string airlineName, address indexed airlineContractAddress);
    event OperatorRegistered(string operatorName, string operatorCode);
    event CustomerRegistered(string name);
    event FlightRegistered(uint flightNum, string flightName);
    event FlightUpdate(uint flightNum, string uMsg);
    event TicketReserved(uint ticketNum, address indexed ticketAddress);
    //event ErrorMessage(string errorMessage);
    //event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    modifier noAirlines() {
        require(msg.sender != address(operatorMap[msg.sender].opAddress), "ERR: No Airlines allowed.");
        _;
    }
    //
    modifier noCustomers() {
        require(msg.sender != address(customerMap[msg.sender].custAddress), "ERR: No Customers allowed.");
        _;
    }
    //
    modifier onlyAirlines() {
        require(msg.sender == address(operatorMap[msg.sender].opAddress), "ERR: Only Airlines");
        _;
    }
    //
    modifier onlyCustomers() {
        require(msg.sender == address(customerMap[msg.sender].custAddress), "ERR: Only Customers");
        _;
    }
    //
    modifier onlyOperator(uint flightNum) {
        require(msg.sender == address(flightMap[flightNum].opAddress), "ERR: Only Operator");
        _;
    }
    //
    modifier onlyCnfrdTickContracts() {
        require(confirmedTickMap[msg.sender].active, "ERR: Only Confirmed Tickets");
        _;
    }
    //
    modifier onlyPndTickContracts() {
        require(reservedTickMap[msg.sender].active, "ERR: Only Reserved Tickets");
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // OTHER/COMMON Functions
    function getflightSts(uint flightNum) public view returns (uint8) {
        require (flightNum == flightMap[flightNum].flightNum, "Unknown Flight");
        return flightMap[flightNum].flightSts;
    }
    //
    function getflightStsTime(uint flightNum) public view returns (uint8, uint, uint, uint, uint) {
        require (flightNum == flightMap[flightNum].flightNum, "UNKNOWN");
        uint8 flightSts = flightMap[flightNum].flightSts;
        uint schDeparturetTS = flightMap[flightNum].schDepTS;
        uint schArrivalTS = flightMap[flightNum].schArrTS;
        uint newDeparturetTS = schDeparturetTS;
        uint newArrivalTS = schArrivalTS;
        //uint currTime = block.timestamp; 
        uint delayTime = (flightMap[flightNum].delayMinutes * 60 seconds);
        if (flightSts <= FL_BRDG && delayTime > 0) {
            // Scheduled + Delay
            newDeparturetTS = schDeparturetTS + delayTime;
            newArrivalTS = schArrivalTS + delayTime;
        } else if (flightSts == FL_LAND) {
            // Actual
            newDeparturetTS = flightMap[flightNum].actDepTS;
            newArrivalTS = flightMap[flightNum].actArrTS;
        } else {
            newDeparturetTS = 0;
            newArrivalTS = 0;
        }
        return (flightSts, schDeparturetTS, newDeparturetTS, newDeparturetTS, newArrivalTS);
    }

    // check flight status
    function checkflightSts(uint flightNum) public view returns (string memory) {
        require (flightNum == flightMap[flightNum].flightNum, "Unknown Flight");
        uint8 fSts = flightMap[flightNum].flightSts; //f lightStatus
        bool tAvl = flightMap[flightNum].tixAvl; // tixAvl
        uint8 rCap = flightMap[flightNum].remSeats; // remSeats
        string memory avl = (
            (tAvl && rCap > 0)
            ? string.concat(" (Avl: ", EagleLib.uintToString(rCap), ")")
            : " (Avl: 0)"
        );
        if (fSts == FL_SCH) {
            return string.concat("SCHEDULED", avl);
        } else if (fSts == FL_ONTIME) {
            return string.concat("ON-TIME", avl);
        } else if (fSts == FL_DLYD) {
            return string.concat("DELAYED", avl);
        } else if (fSts == FL_BRDG) {
            return string.concat("BOARDING", avl);
        } else if (fSts == FL_AIR) {
            return "IN-AIR";
        } else if (fSts == FL_CNCL) {
            return "CANCELLED";
        } else if (fSts == FL_LAND) {
            return "LANDED";
        } else {
            revert("UNKNOWN");
        }
    }

    // Helper function to Unblock seat number after cancellation
    function _unblockSeat(uint flightNum, string memory seatNum) private returns (bool) {
        delete(flightSeatTickMap[flightNum][seatNum]);
        return (flightSeatTickMap[flightNum][seatNum] == address(0) ? true : false);
    }

    /*
    * registerCustomer - Allows Customers to register with Eagle Airlines
    */
    function registerCustomer (string memory custName) noAirlines noCustomers public {
        require(EagleLib.stringLength(custName) > 0, "Name reqd");
        if (customerMap[msg.sender].custAddress == msg.sender) {
            customerMap[msg.sender].custName = custName;
        } else {
            // We've a new customer
            CustomerInfo memory newCustomer = CustomerInfo({
                custAddress: payable(msg.sender),
                custName: custName,
                active: true
            });
            customerMap[msg.sender] = newCustomer;
            //ARMSToken(_tokenARMS).transferFrom(payable(_owner), payable(newCustomer.custAddress), 91*10**18);
            emit CustomerRegistered(custName);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // AIRLINE Functions
    /*
    * _registerAirlineOperator - Airline Operator registration helper function
    */
    //function _registerAirlineOperator (string memory opName, string memory opCode, OpType opType) private returns  (bool success) {
    function registerAirlineOperator (string memory opName, string memory opCode, OpType opType) public  {
        OperatorInfo memory operator = OperatorInfo({
            opAddress: payable(msg.sender),
            opType: opType,
            opName: opName,
            opCode: opCode,
            active: true
        });
        if (operatorMap[operator.opAddress].active) {
            revert ("Existing");
            //revert (string.concat("Existing-", operatorMap[operator.opAddress].opName));
        } else {
            // We've a new Operator; add it to the map
            operatorMap[operator.opAddress] = operator;
            //ARMSToken(_tokenARMS).transferFrom(payable(_owner), payable(operator.opAddress), 95*10**18);
            emit OperatorRegistered(opName, opCode);
        }
    }

       /*
    function registerDomesticOperator (string memory opName, string memory opCode) noCustomers public returns () {
        require(
            _registerAirlineOperator(opName, opCode, OpType.DOM), 
            "ERR: Not Registered"
        );
        emit OperatorRegistered("DOMESTIC", opName, opCode);
    }

    function registerInternationalOperator (string memory opName, string memory opCode) noCustomers public returns () {
        success = _registerAirlineOperator(opName, opCode, OpType.INT);
        require(success, "Failed to Register Airline Operator");
        emit OperatorRegistered("INT", opName, opCode);
    }
    */

    /*
    * setupFlight - Allows Airline operators to setup flight info
    */
    function setupFlight (
            uint flightNum, // unique identifier number
            string memory flightName, //
            uint schDepTS, // original Scheduled departure date & time
            uint schArrTS, // original Scheduled arrival date & time
            string memory origin, // Origin Airport Code
            string memory destination // Destination Airport Code
            //uint seatingCapacity,
            //uint fixedPrice
        ) 
        onlyAirlines public {
        //onlyAirlines public returns (bool success) {
        if (flightMap[flightNum].active) {
            //success = true;
            revert("Existing");
        } else {
            FlightInfo storage flight = flightMap[flightNum];
            flight.flightNum = flightNum;
            flight.opAddress = msg.sender;
            flight.flightName = flightName;
            flight.schDepTS = schDepTS;
            flight.schArrTS = schArrTS;
            flight.actDepTS = 0;
            flight.actArrTS = 0;
            flight.delayMinutes = 0;
            flight.origin = origin;
            flight.destination = destination;
            flight.flightSts = FL_SCH;
            flight.flightStsTS = block.timestamp;
            flight.remSeats = MAX_SEATS;
            flight.tixAvl = true;
            flight.active = true;
            flightMap[flightNum] = flight;
            //success = true;
            emit FlightRegistered(flightNum, flightName);
        }
    }


    /*
    * FLIGHT STATUS UPDATE functions - Allows Airline operator to update Flight status 
    */
    function _updateflightSts (uint flightNum, string memory stsTxt, uint8 flightSts, uint delayMinutes) private returns (bool success) {
        flightMap[flightNum].flightSts = flightSts;
        flightMap[flightNum].flightStsTS = block.timestamp;
        flightMap[flightNum].delayMinutes = delayMinutes;
        if (flightSts == FL_LAND)
            success = _closeFlight(flightNum, flightSts);
        emit FlightUpdate(flightNum, stsTxt);
    }

    function flightSOLDOUT (uint flightNum) onlyOperator(flightNum) 
        public returns (bool success) {
        require (
            flightMap[flightNum].flightSts >= FL_SCH 
            && flightMap[flightNum].flightSts <= FL_BRDG,
            "NOT UPDTable"
        );
        flightMap[flightNum].tixAvl = false;
        flightMap[flightNum].flightStsTS = block.timestamp;
        success = true;
        emit FlightUpdate(flightNum, "SOLDOUT");
    }

    function flightONTIME (uint flightNum) onlyOperator(flightNum)  public returns (bool) {
        return _updateflightSts(flightNum, "ON-TIME", FL_ONTIME, 0);
    }

    function flightDELAYED (uint flightNum, uint estDelayMinutes) onlyOperator(flightNum)  public returns (bool) {
        require(estDelayMinutes > 0, "Inv delay time");
        return _updateflightSts(flightNum, string.concat("DELAYED (min): ", EagleLib.uintToString (estDelayMinutes)), FL_DLYD, estDelayMinutes);
    }

    function flightBOARDING (uint flightNum) onlyOperator(flightNum) public returns (bool) {
        uint currTime = block.timestamp;
        uint calcDelayMinutes = (
            (currTime > flightMap[flightNum].schDepTS)
            ? (currTime - flightMap[flightNum].schDepTS) / 60 seconds
            : flightMap[flightNum].delayMinutes
        );
        flightMap[flightNum].tixAvl = false;
        return _updateflightSts(flightNum, "BOARDING", FL_BRDG, calcDelayMinutes);
    }

    function flightINAIR (uint flightNum) onlyOperator(flightNum) public returns (bool) {
        uint currTime = block.timestamp;
        uint calcDelayMinutes = (
            (currTime > flightMap[flightNum].schDepTS)
            ? (currTime - flightMap[flightNum].schDepTS) / 60 seconds
            : 0
        );
        flightMap[flightNum].actDepTS = currTime;
        return _updateflightSts(flightNum, "IN-AIR", FL_AIR, calcDelayMinutes);
    }

    function flightCANCELLED (uint flightNum) onlyOperator(flightNum) public returns (bool) {
        require (
            flightMap[flightNum].flightSts >= FL_SCH 
            && flightMap[flightNum].flightSts <= FL_BRDG,
            "NOT CNCLable"
        );
        flightMap[flightNum].actDepTS = 0;
        flightMap[flightNum].actArrTS = 0;
        flightMap[flightNum].tixAvl = false;
        return _updateflightSts(flightNum, "CANCELLED", FL_CNCL, 0);
    }

    function flightLANDED (uint flightNum) onlyOperator(flightNum) public returns (bool) {
        require (flightMap[flightNum].flightSts == FL_AIR, "NOT UPDATETABLE");
        uint currTime = block.timestamp;
        uint calcDelayMinutes = (
            (currTime > flightMap[flightNum].schArrTS)
            ? (currTime - flightMap[flightNum].schArrTS) / 60 seconds
            : 0
        );
        flightMap[flightNum].actArrTS = currTime;
        flightMap[flightNum].tixAvl = false;
        return _updateflightSts(flightNum, "LANDED", FL_LAND, calcDelayMinutes);
    }

    /*
    * reserveTicket - Allows customers/agents to reserve a ticket
    */
    // TODO: check modifier
    function reserveTicket(uint flightNum) onlyCustomers  external returns (address) {
        require(flightMap[flightNum].active, "Inv Flight");
        FlightInfo storage flightInfo = flightMap[flightNum];
        require(flightInfo.tixAvl && flightInfo.remSeats > 0, "ERR: NO SEATS AVL");
        // Create Ticket
        TicketInfo memory ticket = TicketInfo({
            ticketContract: address(0),
            ticketNum: ++_tickCntr,
            buyer: address(msg.sender),
            flightNum: flightNum,
            seatNum: "NA",
            ticketAmount: (operatorMap[flightInfo.opAddress].opType == OpType.DOM) ? T_PRICE_DOM : T_PRICE_INT,
            active: true
        });
        // Create Ticket Contract
        address opAddress = flightMap[flightNum].opAddress;
        uint schDepTS = flightMap[flightNum].schDepTS;
        EagleTicket ticketContract = _factory.createTicket(
            _contractAddress,
            opAddress,
            ticket.buyer,
            ticket.ticketNum,
            ticket.flightNum,
            ticket.seatNum,
            ticket.ticketAmount,
            schDepTS
         );
        ticket.ticketContract = address(ticketContract);
        reservedTickMap[ticket.ticketContract] = ticket;
        //flightInfo.remSeats -= 1;
        flightInfo.allTickets.push(address(ticketContract));
        emit TicketReserved(ticket.ticketNum, ticket.ticketContract);
        return (ticket.ticketContract);
    }

    /*
    * Confirm Ticket: Allows buyers to pay and confirm the ticket via the EagleTicket contract instance
    */
    function confirmTicket(address ticketContract, address buyer) onlyPndTickContracts public returns (bool) {
        TicketInfo memory ticket = reservedTickMap[ticketContract];
        uint flightNum = ticket.flightNum;
        require(flightNum > 0, "Inv Ticket");
        CustomerInfo memory customer = customerMap[buyer];
        require(customer.active, "Inv Customer");
        // decrement seating capacity
        require(flightMap[flightNum].remSeats > 0, "No seats avl");
        flightMap[flightNum].remSeats--;       
        // move ticket to confirmed list
        delete(reservedTickMap[ticketContract]);
        confirmedTickMap[ticketContract] = ticket;
        //ticket.pending = false;
        //ticket.confirmed = false;
        return true;
    }

    /*
    * Void Ticket: Allows buyers to cancel reserved tickets
    */
    function voidTicket(address ticketContract) onlyPndTickContracts public returns (bool, string memory) {
        // delete reserved ticket
        TicketInfo memory ticket = reservedTickMap[ticketContract];
        delete(reservedTickMap[ticketContract]);
        closedTickMap[ticketContract] = ticket;
        return (true, "Ticket voided");
    }

    /*
    * Cancel Ticket: Allows buyers to cancel confirmed tickets
    */
    function cancelTicket(address ticketContract) onlyCnfrdTickContracts public returns (bool, string memory) {
        TicketInfo memory ticket = confirmedTickMap[ticketContract];
        uint flightNum = ticket.flightNum;
        require(flightNum > 0, "Inv Ticket");
        // unblock seat
        _unblockSeat (flightNum, ticket.seatNum); // unblock previously held seat
        flightMap[flightNum].remSeats++;
        // move ticket to cancelled list
        delete(confirmedTickMap[ticketContract]);
        closedTickMap[ticketContract] = ticket;
        return (true, "Ticket cancelled");
    }

    function selectSeat (address ticketContract, string memory seatNum) onlyCnfrdTickContracts() public returns (bool success) {
        TicketInfo storage ticket = confirmedTickMap[ticketContract];
        address f_seatTicketContract = flightSeatTickMap[ticket.flightNum][seatNum];
        string memory f_ticketseatNum = (EagleLib.stringCompare(ticket.seatNum, "NA")) ?  "" : ticket.seatNum;
        if (f_seatTicketContract == ticketContract) {
            success = true;
            revert("No change");
        } else if (f_seatTicketContract != ticketContract && f_seatTicketContract != address(0)) {
            success = false;
            revert("Seat blocked");
        } else {
            if (!EagleLib.stringCompare(f_ticketseatNum, seatNum)) {
                _unblockSeat (ticket.flightNum, f_ticketseatNum); // unblock previously held seat
            }
            success = true;
            ticket.seatNum = seatNum;
            flightSeatTickMap[ticket.flightNum][seatNum] = ticketContract;
        }
        //require(success, "ERR: Seat assignment failed");
    }

    function _closeFlight(uint flightNum, uint8 flightSts) onlyOperator(flightNum) private returns (bool success) {
        require(flightSts == FL_CNCL || flightSts == FL_LAND, "ERR: Invalid Flight Status");
        address[] memory allTickets = flightMap[flightNum].allTickets;
        for(uint i = 0; i < allTickets.length; i++) {
            TicketInfo memory ticket;
            if (confirmedTickMap[allTickets[i]].active) {
                ticket = confirmedTickMap[allTickets[i]];
                delete(confirmedTickMap[allTickets[i]]);
            } else {
                ticket = reservedTickMap[allTickets[i]];
                delete(reservedTickMap[allTickets[i]]);
            }
            //
            success = EagleTicket(ticket.ticketContract).closeTicket(flightSts);
            closedTickMap[allTickets[i]] = ticket;             
        }
    }
}