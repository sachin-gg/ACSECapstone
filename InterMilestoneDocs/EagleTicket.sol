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
// To create ARMS Token
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/erc20
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
// To generate and own ARMS Tokens
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable
import "@openzeppelin/contracts/access/Ownable.sol";

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
// Eagle Airline ticket contract - keeps track of the flight details & ticket buyer (customer) details across multiple flights.
contract EagleTicket is Ownable {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    // Airline Type - enumerates various Airline types
    enum AirlineType { DOMESTIC, INTERNATIONAL }
    // TicketStatus - enumerates various ticket states
    enum TicketStatus { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
    // FlightStatus - enumerates various flight states
    enum FlightStatus { DOES_NOT_EXIST, SCHEDULED, ON_TIME, DELAYED, BOARDING, IN_AIR, CANCELLED, LANDED }
    // PaymentStatus - enumerates the payment states
    enum PaymentStatus { TRANSFERRED, PAID_IN_FULL, PAID_IN_PART } 


    // Airline info
    struct AirlineInfo {
        address airlineAddress; // operating airline address
        AirlineType airlineType; // operating airline Type - Domestic / International
        string airlineName; // Name of Airline
        //string airlineCode; // 2-char airline Code
    }
    mapping (address => AirlineInfo) airlineMap;


    // Customer Info
    struct CustomerInfo {
        address customerAddress; // customer address
        string customerName; // customer name
    }
    mapping (address => CustomerInfo) customerMap;


    // FlightInfo - contains all the Flight information
    struct FlightInfo {
        uint flightNumber; // unique identifier number
        address airline; // operating airline address
        string flightName; //
        uint scheduledDatetime; // original Scheduled departure date & time (EPOCH timestamp Format)
        uint revisedDatetime; // revised (delayed/rescheduled) flight date & time (EPOCH timestamp Format)
        uint departureDatetime; // actual departure flight date & time (EPOCH timestamp Format)
        string flightOrigin; // Origin Airport Code
        string flightDestination; // Destination Airport Code
        FlightStatus flightStatus; // last known status of flight
        uint flightStatusDateTime; // last flight status update date time
        uint seatingCapacity; // max number of seats
        bool isFull;
        bool isOpenToBuyTickets;
        uint fixedPrice; // buying price - consider a fixed ticket price for now
    }
    mapping (uint => FlightInfo) private flightMap; // flightNumber => FlightInfo


    // TicketInfo - contains all the Ticket information
    struct TicketInfo {
        uint ticketNumber; // "1234567890123" unique 13-digit number
        address customer; // buyer
        uint flightNumber; // flight
        //string seatCategory; // "Economy"
        string seatNumber; // "24A"
        uint refundAmount; // amount refunded to Customer, if any 
        uint paidAmount; // amount paid to Airline, if any
        TicketStatus ticketStatus; // last known status of ticket
        PaymentStatus paymentStatus; // last known status of payment
        uint ticketStatusDatetime; // last ticket status update date time
        uint paymentStatusDatetime; // last payment status update date time
    }
    mapping (uint => TicketInfo) private ticketMap;
    mapping(uint => mapping(string => uint)) private flightSeatTicketMap; // flightNumber => string seatNumber => uint ticketNumber
    //mapping(uint => string) ticketSeatMap; // uint ticketNumber => string seatNumber


    //
    //address private _ARMSTokenAddress; // Token contract Address
    address private _transferAddress; // Escrow account addrress (this; current EagleTicket contract address) 
    uint private _lastTicketNumber; // Ticket number
    uint8 private _priceDecimals;


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    /*
    constructor (address ARMSTokenAddress) {
        _ARMSTokenAddress = ARMSTokenAddress;
        _EscrowAddress = address(this);
        _lastTicketNumber = 1000000000000;
    }
    */
    constructor () {
        _transferAddress = address(this);
        _lastTicketNumber = 1000000000000;
        _priceDecimals = 18; // 1 eth = 10***18 wei
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event FlightCancelled (address indexed airline, uint flightNumber, string message); // When the flight is Cancelled
    event TicketReserved (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, uint transferredAmount, string message);
    event RefundProcessed (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, uint refundAmount, string message);
    event PaymentProcessed (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, uint paidAmount, string message);


    ///////////////////////////////////////////////////////////////////////////////////////////////
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
        require(msg.sender == address(airlineMap[msg.sender].airlineAddress), "!ERROR! Operation not allowed! Only registered Airlines allowed.");
        _;
    }
    //
    modifier OnlyCustomers() {
        require(msg.sender == address(customerMap[msg.sender].customerAddress), "!ERROR! Operation not allowed! Only registered Customers allowed.");
        _;
    }
    //
    modifier OnlyFlightOperator(uint flightNumber) {
        require(msg.sender != address(flightMap[flightNumber].airline), "!ERROR! Only Flight Operating Airline allowed.");
        _;
    }
    //
    modifier OnlyTicketSeller(uint ticketNumber) {
        require(msg.sender == address(flightMap[ticketMap[ticketNumber].flightNumber].airline), "!ERROR! Operation not allowed! Only Airline Operator allowed.");
        _;
    }
    //
    modifier OnlyTicketBuyer(uint ticketNumber) {
        require(msg.sender == address(ticketMap[ticketNumber].customer), "!ERROR! Operation not allowed! Only Ticket Buyer allowed.");
        _;
    }
    //
    modifier OnlyTicketBuyerOrSeller(uint ticketNumber) {
        require(
                (
                    msg.sender == address(flightMap[ticketMap[ticketNumber].flightNumber].airline)
                    || msg.sender == address(ticketMap[ticketNumber].customer)
                ),
                "!ERROR! Operation not allowed! Only Airline Operator / Ticket Buyer allowed."
            );
        _;
    }
    //
    modifier CheckTicketNumber(uint ticketNumber) {
        // Valid ticket numbers are 13 digits
        require(ticketNumber > 1000000000000 && ticketNumber < 10000000000000, "!ERROR! Invalid Ticket Number provided.");
        _;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // OTHER/COMMON Functions
    // Helper function to get ticket object
    function _getTicket(uint ticketNumber) private view returns (TicketInfo memory ticket) {
        return ticketMap[ticketNumber];
    }

    // Helper function to get flight object
    function _getFlight(uint flightNumber) private view returns (FlightInfo memory flight) {
        return flightMap[flightNumber];
    }

    // Helper function to get flight status message
    function _getFlightStatusMessage (FlightStatus status, bool isFull) private pure returns (string memory) {
        if (status == FlightStatus.DOES_NOT_EXIST) {
            return "!ERROR! Flight not registered.";
        } else if (status == FlightStatus.SCHEDULED) {
            return (isFull) ? "!INFO! Flight is scheduled & full. No more seating available." : "!INFO! Flight is scheduled.";
        } else if (status == FlightStatus.ON_TIME) {
            return (isFull) ? "!INFO! Flight is on-time & full. No more seating available." : "!INFO! Flight is on-time.";
        } else if (status == FlightStatus.DELAYED) {
            return (isFull) ? "!INFO! Flight is delayed & full. No more seating available." : "!INFO! Flight has been delayed.";
        } else if (status == FlightStatus.BOARDING) {
            return "!INFO! Flight is boarding.";
        } else if (status == FlightStatus.IN_AIR) {
            return "!INFO! Flight has departed.";
        } else if (status == FlightStatus.CANCELLED) {
            return "!INFO! Flight has been cancelled.";
        } else if (status == FlightStatus.LANDED) {
            return "!INFO! Flight has reached its destination.";
        } else {
            return "!ERROR! Unknown Flight Status";
        }
    }

    // Helper function to get ticket status message
    function _getTicketStatusMessage (TicketStatus status) private pure returns (string memory) {
        if (status == TicketStatus.DOES_NOT_EXIST) {
            return "!INFO! Invalid Ticket.";
        } else if (status == TicketStatus.RESERVED) {
            return "!INFO! Ticket is Reserved.";
        } else if (status == TicketStatus.CANCELLATION_IN_PROGRESS) {
            return "!INFO! Ticket cancellation is in progress.";
        } else if (status == TicketStatus.CANCELLED) {
            return "!INFO! Ticket has been cancelled.";
        } else {
            return "!ERROR! Unknown Flight Status";
        }
    }

    // Helper function to get ticket status
    function _getTicketStatus (uint ticketNumber) private view returns (TicketStatus) {
        if (_getTicket(ticketNumber).ticketNumber ==  ticketNumber) {
            return ticketMap[ticketNumber].ticketStatus;
        }
        return TicketStatus.DOES_NOT_EXIST;
    }

    // Helper function to check flight status
    function checkFlightStatus(uint flightNumber) public view returns (bool found, string memory message) {
        if (_getFlight(flightNumber).flightNumber == flightNumber) {
            found = true;
            message = _getFlightStatusMessage(flightMap[flightNumber].flightStatus, flightMap[flightNumber].isFull);          
        } else {
             found = false;
             message = _getFlightStatusMessage(FlightStatus.DOES_NOT_EXIST, false);
             revert(message);
        }
        return (found, message);
    }

    // Helper function to Unblock seat number after cancellation
    function _unblockSeat(uint flightNumber, string memory seatNumber) private returns (bool success, string memory) {
        delete(flightSeatTicketMap[flightNumber][seatNumber]);
        return (true, "!INFO! Unblocked Seat.");
    }


    /*
    * refundStatus - Allows Buyers & Sellers to check their refund status
    */
    function refundStatus(uint ticketNumber) OnlyTicketBuyerOrSeller(ticketNumber) public view returns (bool success, string memory message) {
        success = false;
        message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }


    /*
    * checkTicketstatus - Allows Buyers & Sellers to check their ticket status
    */
    function checkTicketstatus(uint ticketNumber) OnlyTicketBuyerOrSeller(ticketNumber) public view returns (bool success, string memory message) {
        TicketStatus ticketStatus = _getTicketStatus(ticketNumber);
        success = (ticketStatus == TicketStatus.DOES_NOT_EXIST) ? false : true;
        message = _getTicketStatusMessage(ticketStatus);
    }
    


    function processRefund(uint ticketNumber) OnlyTicketBuyerOrSeller(ticketNumber) public  view returns (bool success, string memory message) {
        success = false;
        message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }




    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CUSTOMER Functions
    // Customer Registration
    function registerCustomer (string memory customerName) NoAirlines public returns (bool) {
        if (customerMap[msg.sender].customerAddress == msg.sender) {
            customerMap[msg.sender].customerName = customerName;
        } else {
            // We've a new customer
            CustomerInfo memory newCustomer = CustomerInfo({
                customerAddress: msg.sender,
                customerName: customerName
            });
            customerMap[msg.sender] = newCustomer;
        }
        //
        if (customerMap[msg.sender].customerAddress == msg.sender) {
            // Customer registered
            console.log ("Customer Registered: ", msg.sender);
            return (true);
        }
        return (false);
    }


    // !! PAYABLE !!
    function buyticket (uint flightNumber) 
        OnlyCustomers
        public payable returns (bool success, string memory) {
        // flightNumber exists
        FlightInfo memory flight = _getFlight(flightNumber);
        require(flight.flightNumber ==  flightNumber, "!ERROR! Invalid Flight.");
        require(!flight.isFull, "!ERROR! Flight is full. No tickets can be purchased at this time");
        require(flight.isOpenToBuyTickets, "!ERROR! No tickets can be bought for this flight."); 
        // seatNumber is available
        TicketInfo memory ticket = TicketInfo({
            ticketNumber: 0, // update before saving
            customer: address(msg.sender),
            flightNumber: flightNumber,
            seatNumber: "NA",
            refundAmount: 0,
            paidAmount: 0,
            ticketStatus: TicketStatus.RESERVED,
            paymentStatus: PaymentStatus.TRANSFERRED,
            ticketStatusDatetime: block.timestamp,
            paymentStatusDatetime: block.timestamp
        });
        // Transfer funds
        uint256 transferredAmount = (msg.value - (flight.fixedPrice * (10 ** _priceDecimals)));
        payable(msg.sender).transfer(transferredAmount);
        //
        _lastTicketNumber++;
        ticket.ticketNumber = _lastTicketNumber;
        ticketMap[_lastTicketNumber] = ticket;
        emit TicketReserved(flight.airline, msg.sender, flightNumber, ticket.ticketNumber, transferredAmount, "Ticket Purchased!");
        return (true, "!INFO! Ticket Purchased.");
    }


    function cancelticket (uint ticketNumber) OnlyTicketBuyer(ticketNumber) public returns (bool success) {
        TicketStatus status = _getTicketStatus(ticketNumber);
        require(status == TicketStatus.RESERVED, "!ERROR! Ticket cannot be cancelled.");
        // Cancel Ticket
        // TODO: Perform Cancellation
        ticketMap[ticketNumber].ticketStatus = TicketStatus.CANCELLATION_IN_PROGRESS;
        return (false);
    }



    function selectSeat (uint ticketNumber, string memory seatNumber) OnlyTicketBuyer(ticketNumber) public returns (bool success, string memory message) {
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



    function claimRefund (uint ticketNumber) OnlyTicketBuyer(ticketNumber) public  view returns (bool success, string memory message) {
        success = false;
        message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // AIRLINE Functions
    function registerAirline (AirlineType airlineType, string memory airlineName) 
        NoCustomers
        public returns (bool, string memory) {
        require(msg.sender != address(0), "!ERROR! Invalid Airline Address provided.");
        if (airlineMap[msg.sender].airlineAddress == msg.sender) {
            return (true, "!INFO! Airline already setup.");
        } else {
            // We've a new Airline; add it to the map
            AirlineInfo memory airline = AirlineInfo({
                airlineAddress: msg.sender,
                airlineType: airlineType,
                airlineName: airlineName
            });
            airlineMap[msg.sender] = airline;
            return (true, "!INFO! Airline has been setup.");
        }
    }


    function setupFlight (
            uint flightNumber, // unique identifier number
            string memory flightName, //
            uint scheduledDatetime, // original Planned departure date & time 
            string memory flightOrigin, // Origin Airport Code
            string memory flightDestination, // Destination Airport Code
            uint seatingCapacity,
            uint fixedPrice
        ) 
        OnlyAirlines public returns (bool success, string memory message) {
        if (flightMap[flightNumber].flightNumber == flightNumber) {
            success = true;
            message = "!INFO! Flight already setup.";
            revert(message);
        } else {
            FlightInfo memory flight = FlightInfo ({  
                flightNumber: flightNumber,
                airline: msg.sender,
                flightName: flightName,
                scheduledDatetime: scheduledDatetime,
                revisedDatetime: scheduledDatetime,
                departureDatetime: 0,
                flightOrigin: flightOrigin,
                flightDestination: flightDestination,
                flightStatus: FlightStatus.SCHEDULED,
                flightStatusDateTime: block.timestamp,
                seatingCapacity: seatingCapacity,
                isFull: false,
                isOpenToBuyTickets: true,
                fixedPrice: fixedPrice
            });
            flightMap[flightNumber] = flight;
            return (true, "!INFO! Flight has been setup.");
        }
    }


    function updateFlightStatus (uint flightNumber, FlightStatus flightStatus, uint revisedDateTime, bool isFull) 
        OnlyFlightOperator(flightNumber) 
        public returns (bool success, string memory message) {
        FlightStatus found_flightStatus = flightMap[flightNumber].flightStatus;
        if (found_flightStatus == FlightStatus.DOES_NOT_EXIST) {
            success = false;
            message = _getFlightStatusMessage(found_flightStatus, false);
        } else {
            // !!!! REVISIT: Perform Validations before updating status !!!!
            if (flightStatus == FlightStatus.CANCELLED) { 
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isOpenToBuyTickets = false;
                success = true;
            } else if (flightStatus == FlightStatus.ON_TIME) {
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isFull = isFull;
                flightMap[flightNumber].isOpenToBuyTickets = (isFull) ? false : true;
                success = true;
                flightMap[flightNumber].revisedDatetime = flightMap[flightNumber].scheduledDatetime;
            } else if (flightStatus == FlightStatus.DELAYED) {
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isFull = isFull;
                flightMap[flightNumber].isOpenToBuyTickets = (isFull) ? false : true;
                success = true;
                flightMap[flightNumber].revisedDatetime = flightMap[flightNumber].scheduledDatetime;
            } else if (flightStatus == FlightStatus.BOARDING) {
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isOpenToBuyTickets = false;
                success = true;
                flightMap[flightNumber].departureDatetime = revisedDateTime;
            } else if (flightStatus == FlightStatus.IN_AIR) {
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isOpenToBuyTickets = false;
                success = true;
                flightMap[flightNumber].departureDatetime = revisedDateTime;
            } else if (flightStatus == FlightStatus.LANDED) {
                flightMap[flightNumber].flightStatus = flightStatus;
                flightMap[flightNumber].isOpenToBuyTickets = false;
                success = true;
                flightMap[flightNumber].departureDatetime = revisedDateTime;
            } else {
                success = false;
                message = "!ERROR! Invalid Status Value";
            }
            //
            if (success) {
                flightMap[flightNumber].flightStatusDateTime = block.timestamp;
                message = _getFlightStatusMessage(flightStatus, isFull);
            }
        }
        return (success, message);
    }
}