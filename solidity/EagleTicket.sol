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
import "./EagleAirline.sol";
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
/* Conventions to follow: https://docs.soliditylang.org/en/latest/style-guide.html
Layout contract elements in the following order:
    Pragma statements
    Import statements
    Interfaces
    Libraries
    Contracts

Inside each contract, library or interface, use the following order:
    Type declarations
    State variables
    Events
    Errors
    Modifiers
    Functions

Order of Functions: Functions should be grouped according to their visibility and ordered:
    constructor
    receive function (if exists)
    fallback function (if exists)
    external
    public
    internal
    private

The modifier order for a function should be:
    Visibility
    Mutability
    Virtual
    Override
    Custom modifiers

!! TODO: Research -  NatSpec
    /// Return the stored value.
    /// @param x the new value to store
    /// @dev retrieves the value of the state variable `storedData`
    /// @return the stored value
*/
///////////////////////////////////////////////////////////////////////////////////////////////
// Eagle Airline contract - keeps track of the Arilines & flight details & ticket buyer (customer) details across multiple flights.
contract EagleTicket {
    //
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
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
    // TicketStatus - enumerates various ticket states
    //enum TicketStatus { DOES_NOT_EXIST, RESERVED, CANCELLATION_IN_PROGRESS, CANCELLED }
    uint8 public constant TICKET_DOES_NOT_EXIST = 0;
    uint8 public constant TICKET_VOID = 1;
    uint8 public constant TICKET_RESERVED = 2;
    uint8 public constant TICKET_CONFIRMED = 3;
    uint8 public constant TICKET_CANCELLATION_IN_PROGRESS = 4;
    uint8 public constant TICKET_CANCELLED = 5;
    // PaymentStatus - enumerates the payment states
    //enum PaymentStatus { TRANSFERRED, PAID_IN_FULL, PAID_IN_PART } 
    uint8 public constant PAYMENT_PENDING = 0;
    uint8 public constant PAYMENT_COLLECTED = 1;
    uint8 public constant PAYMENT_REFUNDED = 2; // Settled by full refund to customer
    uint8 public constant PAYMENT_SPLIT = 3; // Settled by part refund to customer + part payment to airline
    uint8 public  constant PAYMENT_PAID = 4; // Settled by full payment to airline
    //
    address private _ticketContract; // this, contract address
    uint private _ticketNumber; // "1234567890123" unique 13-digit number    
    address private _eagleAirContract; // parent EagleAirline contract address
    address private _superUser; // superUser address
    EagleAirline private _eagleAirline; // parent EagleAirline object (_eagleAirContract)
    address payable private _operatorAddress; // parent, EagleAirline Operator (Domestice, International) address
    address payable private _buyerAddress; // buyer who bought this ticket - customer address
    uint8 private _ticketStatus; // last known status of ticket
    uint8 private _paymentStatus; // last known status of payment
    uint private _ticketTimeStamp; // time when this was created
    uint private _ticketStatusTimeStamp; // last ticket status update date time
    uint private _paymentStatusTimeStamp; // last payment status update date time
    // additional TicketInfo
    struct TicketInfo {
        //address customer; // buyer
        uint flightNumber; // flight
        //string seatCategory; // "Economy"
        string seatNumber; // "A24"
        uint ticketAmount;
        uint collectedAmount;
        uint refundAmount; // amount refunded to Customer, if any 
        uint paidAmount; // amount paid to Airline, if any
        uint collectedTimeStamp;
        uint settledTimeStamp;
        uint schDepartureTimeStamp;
        //uint8 ticketStatus; // last known status of ticket
        //uint8 paymentStatus; // last known status of payment
        //uint ticketStatusDatetime; // last ticket status update date time
        //uint paymentStatusDatetime; // last payment status update date time
    }
    TicketInfo private _ticketInfo;
    //


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    constructor (
        address superUser,
        address operatorAddress,
        address buyerAddress,
        uint ticketNumber,
        uint flightNumber,
        string memory seatNumber,
        uint ticketAmount,
        uint schDepartureTimeStamp
    ) {
        require(operatorAddress != address(0), "Error: Invalid Airline address");
        require(buyerAddress != address(0), "Error: Invalide Customer address");
        require(ticketNumber > 0, "Error: Invalid Ticket #");
        require(flightNumber > 0, "Error: Invalid Flight #");
        require(ticketAmount > 0, "Error: Invalid Ticket Amount");

        _ticketContract = address(this);
        _eagleAirContract = address(msg.sender); // Only the parent can create this contract
        _eagleAirline = EagleAirline(_eagleAirContract);
        _operatorAddress = payable(operatorAddress);
        _buyerAddress = payable(buyerAddress);
        _superUser = superUser;
        _ticketNumber = ticketNumber;
        // additional info
        _ticketStatus = TICKET_RESERVED;
        _paymentStatus = PAYMENT_PENDING;
        _ticketTimeStamp = block.timestamp;
        _ticketInfo = TicketInfo({
            flightNumber: flightNumber,
            seatNumber: seatNumber,
            ticketAmount: ticketAmount,
            collectedAmount: 0,
            refundAmount: 0,
            paidAmount: 0,
            collectedTimeStamp: 0,
            settledTimeStamp: 0,
            schDepartureTimeStamp: schDepartureTimeStamp
        });
        //
        emit ContractCreated("Ticket Contract", address(this));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string contractName, address indexed contractAddress);
    event ViewTicket(uint ticketNumber, uint flightNumber, string seatNumber, string ticketStatus, string paymentStatus);
    event TicketUpdate(uint ticketNumber, string updateMessage);
    event TicketCancelled (uint ticketNumber, string cancelMessage);
    event TicketReserved (uint flightNumber, uint ticketNumber, uint transferredAmount, string message);
    //event TicketCancelled (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, string message);
    event ErrorMessage(string errorMessage);
    event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    modifier OnlyOperator() {
        require(
            (
                msg.sender == address(_operatorAddress)
                || msg.sender == address(_superUser)
            ), 
            "Only Airline Flight Operator allowed"
        );
        _;
    }
    //
    modifier OnlyBuyer() {
         require(
            (
                msg.sender == address(_buyerAddress)
                || msg.sender == address(_superUser)
            ), 
            "Only Ticket Buyer allowed"
        );
        _;
    }
    //
    modifier OnlyBuyerOrOpertor() {
        require(
                (
                    msg.sender == address(_operatorAddress)
                    || msg.sender == address(_buyerAddress)
                    || msg.sender == address(_superUser)
                ),
                "Only Airline Flight Operator / Ticket Buyer allowed"
            );
        _;
    }
    //
    modifier CheckTicketNumber(uint ticketNumber) {
        // Valid ticket numbers are 13 digits
        require(ticketNumber > 1000000000000 && ticketNumber < 10000000000000, "Invalid Ticket Number provided");
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // OTHER/COMMON Functions
     // Helper function to get ticket status text
    function _getTicketStatusText (uint status) private pure returns (string memory) {
        if (status == TICKET_RESERVED) {
            return "RESERVED";
        } else if (status == TICKET_CONFIRMED) {
            return "CONFIRMED";
        } else if (status == TICKET_CANCELLATION_IN_PROGRESS) {
            return "CANCELLATION-IN-PROGRESS";
        } else if (status == TICKET_CANCELLED) {
            return "CANCELLED";
        } else {
            return "UNKNOWN";
        }
    }
    //
    // Helper function to get ticket status text
    function _getPaymentStatusText (uint status) private pure returns (string memory) {
        if (status == PAYMENT_PENDING) {
            return "PENDING";
        } else if (status == PAYMENT_COLLECTED) {
            return "COLLECTED";
        } else if (status == PAYMENT_REFUNDED) {
            return "REFUNDED";
        } else if (status == PAYMENT_SPLIT) {
            return "SPLIT";
        } else if (status == PAYMENT_PAID) {
            return "PAID";
        } else {
            return "UNKNOWN";
        }
    }   
    /*
    * VIEW TICKET INFO - Allows customers to get view ticket information
    */
    function viewTicketInfo() OnlyBuyerOrOpertor public {
        string memory ticketStatus = _getTicketStatusText(_ticketStatus);
        string memory paymentStatus = _getPaymentStatusText(_paymentStatus);
        emit ViewTicket (
            _ticketNumber,
            _ticketInfo.flightNumber, 
            _ticketInfo.seatNumber, 
            ticketStatus,
            paymentStatus
        );
    }

    /*TODO:
    claimRefund - buyer
    
    flightCancelled - operator
    flightComplete - operator
    autoCancel - operator
    */


    // !! PAYABLE !!
    /*
    * COMPLETE PURCHASE - Allows buyers to pay & complete payment for the ticket
    */
    function completePayment ()
        OnlyBuyer
        public payable 
        returns (bool success) {
        success = false;
        uint ticketPrice =  _ticketInfo.ticketAmount;
        require(msg.value > ticketPrice, "Insufficient Amount provided to complete purchase");
        //uint collectedAmount;
        //uint8 ticketStatus = _ticketStatus;
        //uint8 paymentStatus = _paymentStatus;
        //uint ticketStatusTimeStamp = _ticketStatusTimeStamp;
        //uint paymentStatusTimeStamp = _paymentStatusTimeStamp;
        // Confirm with Airline
        success = _eagleAirline.confirmTicket(_ticketContract);
        require(success, "ERR: Ticket purchase failed");
        // Transfer funds, if any back to customer (sender)
        //uint256 transferredAmount = (msg.value - (flight.fixedPrice * (10 ** _priceDecimals)));
        uint256 transferAmount = (
            msg.value - ticketPrice
        );
        string memory message;
        if (transferAmount > 0) {
            //payable(msg.sender).transfer(transferAmount);
            (bool callSuccess, ) = payable(msg.sender).call{value: transferAmount}("");
            require(callSuccess, "ERR: Ticket purchase failed");
            //
            _ticketStatus = TICKET_CONFIRMED;
            _paymentStatus = PAYMENT_COLLECTED;
            success = true;
            message = string.concat("INFO: Ticket Purchased. Ticket # ", EagleLib.uintToString(_ticketNumber));
            emit TicketReserved(_ticketInfo.flightNumber, _ticketNumber, transferAmount, message);
        } else {
            success = true;
            message = "ERR: Insufficient funds to purchase Ticket.";
            revert (message);
        }        
        //
        _ticketInfo.collectedAmount = ticketPrice;
        _ticketStatus = TICKET_CONFIRMED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatus = PAYMENT_COLLECTED;
        _paymentStatusTimeStamp = block.timestamp;
        emit TicketUpdate(_ticketNumber, "! Ticket Payment Confirmed !");
    }

    /*
    * SELECT SEAT - Allows buyers to select/change seats
    */
    function selectSeat (string memory seatNumber) OnlyBuyer public payable returns (bool) {
        return _eagleAirline.selectSeat(_ticketContract, seatNumber);
    }

    // !! PAYABLE !!
    function cancelTicket () OnlyBuyer public payable returns (bool success, string memory message) {
        /*
        * Cancellation by Customer rules
        * Rule: Based on DIFFERENCE of (Scheduled Departure Datetime – Cancellation Datetime)
        *   RESERVED (Unconfirmed) tickets can be cancelled (voided) anytime without penalty. They will automatically be VOID after Flight take-off.
        *   If >= 24 hours	100%
        *   If >= 4 hours and < 24 hours	80%
        *   If >= 2 hour and < 4 hours	40%
        *   If < 2 hour	NOT ALLOWED (revert transaction)
        */
        // Check ticket status
        if (_ticketStatus == TICKET_RESERVED) {
            (success, message) = _eagleAirline.voidTicket(_ticketContract);
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = block.timestamp;
            emit TicketCancelled(_ticketNumber, message);
            //selfdestruct(_buyerAddress);
        } else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS) {
            revert ("Err: Prev CANCELLATION IN PROGRESS");
        } else if (_ticketStatus == TICKET_CANCELLED) {
            revert ("Err: Ticket already CANCELLED");
        }
        uint8 flightStatus = _eagleAirline.getFlightStatus(_ticketInfo.flightNumber);
        require(
            flightStatus >= FLIGHT_SCHEDULED && flightStatus <= FLIGHT_DELAYED,
            "ERR: Ticket cannot be cancelled. Check Flight status"
        );
        uint secondDiff = (_ticketInfo.schDepartureTimeStamp > block.timestamp) ? _ticketInfo.schDepartureTimeStamp - block.timestamp : 0;
        // If < 2 hour	NOT ALLOWED (revert transaction)
        require(secondDiff >= 2 hours, "ERR: Ticket cancellation window closed");
        _ticketStatus = TICKET_CANCELLATION_IN_PROGRESS;
        _ticketStatusTimeStamp = block.timestamp;
        // Calculate refund
        uint8 percentRefund = 0;
        if (secondDiff >= 24 hours)
            percentRefund = 100;
        else if (secondDiff >= 4 hours && secondDiff < 24 hours)
            percentRefund = 80;
        else if (secondDiff >= 2 hours && secondDiff < 4 hours)
            percentRefund = 40;
        else
            revert ("ERR: Ticket cancellation window closed");
        //
        uint256 refundAmount;
        uint256 penaltyAmount;
        // Transfer funds
        bool refundCallSuccess;
        bool penaltyCallSuccess;
        if (address(this).balance > _ticketInfo.collectedAmount) {     
            refundAmount = _ticketInfo.collectedAmount * (percentRefund / 100);
            penaltyAmount = _ticketInfo.collectedAmount - refundAmount; // balance
            // Refund the Buyer
            if (refundAmount > 0) {
                (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                require(refundCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
            // Send balance to Airline
            if (penaltyAmount > 0) {
                (penaltyCallSuccess, ) = payable(_operatorAddress).call{value: penaltyAmount}("");
                require(penaltyCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
        } else {
            message = "ERR: Insufficient funds. Contact customer support.";
            revert (message);
        }
        require(refundCallSuccess || penaltyCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
        //
        _ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatusTimeStamp = _ticketStatusTimeStamp;
        if (refundAmount > 0 && penaltyAmount > 0) {
            _paymentStatus = PAYMENT_SPLIT;
        } else if (refundAmount > 0 && penaltyAmount == 0) {
            _paymentStatus = PAYMENT_REFUNDED;
        } else if (refundAmount == 0 && penaltyAmount > 0) {
            _paymentStatus = PAYMENT_PAID;
        }
        //_unblockSeat (flight.flightNumber, ticket.seatNumber); // unblock previously held seat
        _ticketInfo.seatNumber = "NA";
        _ticketInfo.refundAmount = refundAmount;
        _ticketInfo.paidAmount = penaltyAmount;
        // Confirm with Airline
        (success, message) = _eagleAirline.cancelTicket(_ticketContract);
        require(success, message); 
        success = true;
        message = string.concat("INFO: Ticket Cancelled. Ticket # ", EagleLib.uintToString(_ticketNumber));
        emit TicketCancelled (_ticketNumber, message);
    }

    // !! PAYABLE !!
    function closeTicket (uint8 flightStatus) OnlyOperator public payable returns (bool success) {
        // Check ticket status
        string memory message;
        require(flightStatus == FLIGHT_CANCELLED || flightStatus == FLIGHT_LANDED, "ERR: Invalid Flight Status");
        if (_ticketStatus == TICKET_RESERVED) {
            //(success, message) = _eagleAirline.voidTicket(_ticketContract);
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = block.timestamp;
            emit TicketCancelled(_ticketNumber, message);
        }
        uint256 refundAmount;
        uint256 payAmount;
        // Transfer funds
        bool refundCallSuccess;
        bool payCallSuccess;
        if (address(this).balance > _ticketInfo.collectedAmount) {     
            refundAmount = (flightStatus == FLIGHT_CANCELLED) ? _ticketInfo.collectedAmount : 0;
            payAmount = (flightStatus == FLIGHT_LANDED) ? _ticketInfo.collectedAmount : 0;
            // Refund the Buyer
            if (refundAmount > 0) {
                (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                require(refundCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
            // Send balance to Airline
            if (payAmount > 0) {
                (payCallSuccess, ) = payable(_operatorAddress).call{value: payAmount}("");
                require(payCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
        } else {
            message = "ERR: Insufficient funds. Contact customer support.";
            revert (message);
        }
        require(refundCallSuccess || payCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
        //
        _ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatusTimeStamp = _ticketStatusTimeStamp;
        if (refundAmount > 0 && payAmount > 0) {
            _paymentStatus = PAYMENT_SPLIT;
        } else if (refundAmount > 0 && payAmount == 0) {
            _paymentStatus = PAYMENT_REFUNDED;
        } else if (refundAmount == 0 && payAmount > 0) {
            _paymentStatus = PAYMENT_PAID;
        }
        //_unblockSeat (flight.flightNumber, ticket.seatNumber); // unblock previously held seat
        _ticketInfo.seatNumber = "NA";
        _ticketInfo.refundAmount = refundAmount;
        _ticketInfo.paidAmount = payAmount;
        success = true;
        message = string.concat("INFO: Ticket Cancelled. Ticket # ", EagleLib.uintToString(_ticketNumber));
        emit TicketCancelled (_ticketNumber, message);
    }

    // !! PAYABLE !!
    function claimRefund () OnlyBuyer public payable returns (bool success, string memory message) {
        /*
        * Delayed by Airline – Penalty Rules
        * Rule: Based on DIFFERENCE of (Scheduled Departure Datetime – Actual Departure Datetime)
        *   If > 2 hours and <= 10 hours	10%
        *   If > 10 hours and <= 24 hours	40%
        *   If > 24 hours	100%
        *   If Actual Departure Datetime is not updated within 24 hours from Scheduled Departure Datetime	100%
        */
        // Check ticket status
        if (_ticketStatus == TICKET_RESERVED) {
            (success, message) = _eagleAirline.voidTicket(_ticketContract);
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = block.timestamp;
            emit TicketCancelled(_ticketNumber, message);
            //selfdestruct(_buyerAddress);
        } else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS) {
            revert ("Err: Prev CANCELLATION IN PROGRESS");
        } else if (_ticketStatus == TICKET_CANCELLED) {
            revert ("Err: Ticket already CANCELLED");
        }
        uint8 flightStatus = _eagleAirline.getFlightStatus(_ticketInfo.flightNumber);
        require(
            flightStatus >= FLIGHT_SCHEDULED && flightStatus <= FLIGHT_DELAYED,
            "ERR: Ticket cannot be cancelled. Check Flight status"
        );
        uint secondDiff = (_ticketInfo.schDepartureTimeStamp > block.timestamp) ? _ticketInfo.schDepartureTimeStamp - block.timestamp : 0;
        // If < 2 hour	NOT ALLOWED (revert transaction)
        require(secondDiff >= 2 hours, "ERR: Ticket cancellation window closed");
        _ticketStatus = TICKET_CANCELLATION_IN_PROGRESS;
        _ticketStatusTimeStamp = block.timestamp;
        // Calculate refund
        uint8 percentRefund = 0;
        if (secondDiff >= 24 hours)
            percentRefund = 100;
        else if (secondDiff >= 4 hours && secondDiff < 24 hours)
            percentRefund = 80;
        else if (secondDiff >= 2 hours && secondDiff < 4 hours)
            percentRefund = 40;
        else
            revert ("ERR: Ticket cancellation window closed");
        //
        uint256 refundAmount;
        uint256 penaltyAmount;
        // Transfer funds
        bool refundCallSuccess;
        bool penaltyCallSuccess;
        if (address(this).balance > _ticketInfo.collectedAmount) {     
            refundAmount = _ticketInfo.collectedAmount * (percentRefund / 100);
            penaltyAmount = _ticketInfo.collectedAmount - refundAmount; // balance
            // Refund the Buyer
            if (refundAmount > 0) {
                (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                require(refundCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
            // Send balance to Airline
            if (penaltyAmount > 0) {
                (penaltyCallSuccess, ) = payable(_operatorAddress).call{value: penaltyAmount}("");
                require(penaltyCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            }
        } else {
            message = "ERR: Insufficient funds. Contact customer support.";
            revert (message);
        }
        require(refundCallSuccess || penaltyCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
        //
        _ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatusTimeStamp = _ticketStatusTimeStamp;
        if (refundAmount > 0 && penaltyAmount > 0) {
            _paymentStatus = PAYMENT_SPLIT;
        } else if (refundAmount > 0 && penaltyAmount == 0) {
            _paymentStatus = PAYMENT_REFUNDED;
        } else if (refundAmount == 0 && penaltyAmount > 0) {
            _paymentStatus = PAYMENT_PAID;
        }
        //_unblockSeat (flight.flightNumber, ticket.seatNumber); // unblock previously held seat
        _ticketInfo.seatNumber = "NA";
        _ticketInfo.refundAmount = refundAmount;
        _ticketInfo.paidAmount = penaltyAmount;
        // Confirm with Airline
        (success, message) = _eagleAirline.cancelTicket(_ticketContract);
        require(success, message); 
        success = true;
        message = string.concat("INFO: Ticket Cancelled. Ticket # ", EagleLib.uintToString(_ticketNumber));
        emit TicketCancelled (_ticketNumber, message);
    }
}