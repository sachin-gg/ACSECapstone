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

import "./EagleAirline.sol";

contract EagleCustomers {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string contractName, address indexed contractAddress);
    event CustomerRegistered(string customerName);
    event ErrorMessage(string errorMessage);
    event InfoMessage(string infoMessage);
    // Customer Info
    struct CustomerInfo {
        address payable customerAddress; // customer address
        string customerName; // customer name
    }
    mapping (address => CustomerInfo) customerMap; // customerAddress => CustomerInfo
    mapping (address => address) customerTicketMap; // customerAddress => ticketAddress
    //
    address private _eagleAirlinesContract;
    address private _eagleAdmin;
    EagleAirline _eagleAir;
    address[] private customers;
    
    
    mapping(address => address[]) bookingHistory;
    
    constructor(address eagleAirlinesContract) {
        require(eagleAirlinesContract != address(0), "Error: Invalid Eagle Airline contract");
        _eagleAdmin = msg.sender;
        //
        _eagleAirlinesContract = _airlineContract;
        _eagleAir = EagleAirline(eagleAirlinesContract);
        //
        ContractCreated("EagleCustomers", address(this));
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Error: Only admin can do this action");
        _;
    }
    
    function bookTicket(uint flightNo, string calldata flightDate) public returns (address ticketAddr) {
        customers.push(msg.sender);
        address ticket = airline.createTicket(flightNo, flightDate, msg.sender);
        bookingHistory[msg.sender].push(ticket);
        return ticket;
    }
    
    function getMyBookings() public view returns(address[] memory){
        return bookingHistory[msg.sender];
    }
    
    function setAirline(address _airlineContract) public onlyAdmin {
        require(_airlineContract != address(0), "Error: Invalid address for airline contract");
        airlineContract = _airlineContract;
        airline = EagleAirline(airlineContract);
    }
    
    function getAirline() public view onlyAdmin returns (address) {
        return airlineContract;
    }
    
    function searchFlight( string calldata origin, string calldata dest, string calldata travelDate) public view returns (uint) {
        EagleAirline Eagleairline = EagleAirline(airlineContract);
        uint flightNo = Eagleairline.searchFlight(  origin,  dest, travelDate);
        return flightNo;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CUSTOMER/BUYER Functions
    /*
    * registerCustomer - Allows Customers to register with Eagle Airlines
    */
    function cust_registerCustomer (string memory customerName) NoAirlines public returns (bool) {
        require(EagleLib.stringLength(customerName) > 0, "!ERROR! Customer Name is required.");
        if (customerMap[msg.sender].customerAddress == msg.sender) {
            customerMap[msg.sender].customerName = customerName;
        } else {
            // We've a new customer
            CustomerInfo memory newCustomer = CustomerInfo({
                customerAddress: payable(msg.sender),
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

    /*
    * buyTicket - Allows resgistered Customers to buy Tickets
    */
    // !! PAYABLE !!
    function cust_buyTicket (uint flightNumber) 
        OnlyCustomers
        public payable returns (bool success, string memory message) {
        success = false;
        message = "!ERROR! Failed to complete ticket purchase!";
        // flightNumber exists
        FlightInfo memory flight = _getFlight(flightNumber);
        require(flight.flightNumber ==  flightNumber, "!ERROR! Invalid Flight.");
        require(!flight.isFull, "!ERROR! Flight is full. No tickets can be purchased at this time.");
        require(!flight.isClosed, "!ERROR! Ticket Purchasing is closed for this Flight at this time."); 
        // seatNumber is available
        TicketInfo memory ticket = TicketInfo({
            ticketNumber: 0, // update before saving
            customer: address(msg.sender),
            flightNumber: flightNumber,
            seatNumber: "NA",
            refundAmount: 0,
            paidAmount: 0,
            ticketStatus: EagleLib.Ticket_DOES_NOT_EXIST,
            paymentStatus: EagleLib.Payment_PENDING,
            ticketStatusDatetime: block.timestamp,
            paymentStatusDatetime: block.timestamp
        });
        // Transfer funds, if any back to customer (sender)
        //uint256 transferredAmount = (msg.value - (flight.fixedPrice * (10 ** _priceDecimals)));
        uint256 transferAmount = (
            msg.value - 
            (
                // flight.fixedPrice * (10 ** _priceDecimals))
                (airlineMap[flight.airline].airlineType == AirlineType.DOMESTIC ) ? TICKET_PRICE_DOMESTIC : TICKET_PRICE_INTERNATIONAL 
            )
        );
        if (transferAmount > 0) {
            //payable(msg.sender).transfer(transferAmount);
            (bool callSuccess, ) = payable(msg.sender).call{value: transferAmount}("");
            require(callSuccess, "!ERROR! Ticket purchase failed.");
            //
            _lastTicketNumber++;
            ticket.ticketNumber = _lastTicketNumber;
            ticket.ticketStatus = EagleLib.Ticket_RESERVED;
            ticket.paymentStatus = EagleLib.Payment_COLLECTED;
            ticketMap[_lastTicketNumber] = ticket;
            success = true;
            message = string.concat("!INFO! Ticket Purchased. Ticket # ", EagleLib.uintToString(ticket.ticketNumber));
            emit TicketReserved(flight.airline, msg.sender, flightNumber, ticket.ticketNumber, transferAmount, message);
        } else {
            success = true;
            message = "!ERROR! Insufficient funds to purchase Ticket.";
            revert (message);
        }        
    }

    /*
    * cancelTicket - Allows Buyers to cancel Tickets
    */
    // !! PAYABLE !!
    function buyer_cancelTicket (uint ticketNumber) OnlyTicketBuyer(ticketNumber) public payable returns (bool success, string memory message) {
        success = false;
        message = "!ERROR! Ticket cannot be cancelled. Please contact customer support."; // default error message
        // Check ticket status
        TicketInfo memory ticket = ticketMap[ticketNumber];
        // require(ticketStatus == EagleLib.Ticket_RESERVED, "!ERROR! Ticket cannot be cancelled.");
        if (ticket.ticketStatus == EagleLib.Ticket_CANCELLATION_IN_PROGRESS) {
            message = "!ERROR! Ticket CANCELLATION request is already in progress!";
            revert (message);
        } else if (ticket.ticketStatus == EagleLib.Ticket_CANCELLED) {
            message = "!ERROR! Ticket is already CANCELLED!";
            revert (message);
        }
        // Check flight status
        FlightInfo memory flight = _getFlight(ticketMap[ticketNumber].flightNumber);
        require (
            flight.flightStatus >= EagleLib.Flight_SCHEDULED && flight.flightStatus <= EagleLib.Flight_DELAYED,
            "!ERROR! Ticket cancellation is no longer possible for this flight. Check Flight status!"
        );
        require (
            (
                ((flight.schDepartureDatetime < flight.revDepartureDatetime) ? flight.revDepartureDatetime : flight.schDepartureDatetime)
                > block.timestamp
            ), 
            "!ERROR! Ticket cancellation is on longer possible for this flight. Check Flight status & departure time!"
        );
        /*
        * Cancellation by Customer rules
        *   If >= 24 hours	100%
        *   If >= 4 hours and < 24 hours	80%
        *   If >= 2 hour and < 4 hours	40%
        *   If < 2 hour	NOT ALLOWED (revert transaction)
        */
        uint timeDiff = EagleLib.getTSTimeDiff(
            block.timestamp,
            (flight.schDepartureDatetime < flight.revDepartureDatetime) ? flight.revDepartureDatetime : flight.schDepartureDatetime,
            EagleLib.DatePart.HOUR
        );
        uint8 percentRefund = 0;
        if (timeDiff >= 24) {
            percentRefund = 100;
        } else if (timeDiff >= 4 && timeDiff < 24) {
            percentRefund = 80;
        } else if (timeDiff >= 2 && timeDiff < 4) {
            percentRefund = 40;
        } else {
            percentRefund = 0;
            message =  "!ERROR! Ticket cancellation window has closed. Please contact customer support.";
            revert (message);
        }  
        //
        uint ticketPrice = (airlineMap[flight.airline].airlineType == AirlineType.DOMESTIC) ? TICKET_PRICE_DOMESTIC : TICKET_PRICE_INTERNATIONAL;
        uint256 refundAmount;
        uint256 paidAmount;
        address customer = msg.sender;
        address airline = airlineMap[flight.airline].airlineAddress;
        // Transfer funds
        if (address(this).balance > ticketPrice) {
            //flight.airline.transfer(ticketMap[ticketNumber].customer)           
            refundAmount = ticketPrice * (percentRefund / 100);
            paidAmount = ticketPrice - refundAmount; // balance
            // Refund the Buyer
            if (refundAmount > 0) {
                (bool callSuccess, ) = payable(customer).call{value: refundAmount}("");
                require(callSuccess, "!ERROR! Ticket cancellation failed. Please contact customer support.");
            } else {
                message = "!ERROR! Insufficient funds to purchase Ticket.";
                revert (message);
            }
            // Send balance to Airline
            if (paidAmount > 0) {
                (bool callSuccess, ) = payable(airline).call{value: paidAmount}("");
                require(callSuccess, "!ERROR! Ticket cancellation failed. Please contact customer support.");
            } else {
                message = "!ERROR! Insufficient funds to purchase Ticket.";
                revert (message);
            }
        } else {
                message = "!ERROR! Insufficient funds to purchase Ticket.";
                revert (message);
        }
        //
        ticket.ticketStatus = EagleLib.Ticket_CANCELLED;
        if (refundAmount > 0 && paidAmount > 0) {
            ticketMap[ticketNumber].paymentStatus = EagleLib.Payment_SPLIT;
        } else if (refundAmount > 0 && paidAmount == 0) {
            ticketMap[ticketNumber].paymentStatus = EagleLib.Payment_REFUNDED;
        } else if (refundAmount == 0 && paidAmount > 0) {
            ticketMap[ticketNumber].paymentStatus = EagleLib.Payment_PAID;
        }
        //string memory seatNumber = ticket.seatNumber;
        _unblockSeat (flight.flightNumber, ticket.seatNumber); // unblock previously held seat
        ticket.seatNumber = "NA";
        success = true;
        message = string.concat("!INFO! Ticket Cancelled. Ticket # ", EagleLib.uintToString(ticketNumber));
        ticketMap[ticketNumber] = ticket;
        //event TicketCancelled (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, uint refundAmount, uint paidAmount, string message);
        //emit TicketCancelled (airline, customer, flight.flightNumber, ticketNumber, message);
    }

    /*
    * selectSeat - Allows Buyers to select / chainge Seat number
    */
    function buyer_selectSeat (uint ticketNumber, string memory seatNumber) OnlyValidTicketNumbers(ticketNumber) OnlyTicketBuyer(ticketNumber) public returns (bool success, string memory message) {
        //require(ticketMap[ticketNumber].ticketNumber == ticketNumber, "!ERROR! Invalid Ticket Number.");
        uint found_flightNumber = ticketMap[ticketNumber].flightNumber;
        uint found_seatTicketNumber = flightSeatTicketMap[found_flightNumber][seatNumber];
        string memory found_ticketSeatNumber = (EagleLib.stringCompare(ticketMap[ticketNumber].seatNumber, "NA")) ?  "" : ticketMap[ticketNumber].seatNumber;
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
                !EagleLib.stringCompare(found_ticketSeatNumber, seatNumber)
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

    /*
    * selectSeat - Allows Buyers enter a refund claim
    */
    function buyer_claimRefund (uint ticketNumber) OnlyTicketBuyer(ticketNumber) public  view returns (bool success, string memory message) {
        success = false;
        message = "!TODO! Pending implementation"; // remove view after implementation
        revert(message);
    }

}
