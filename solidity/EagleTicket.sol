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
contract EagleTicket {
    //
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    // FlightStatus - enumerates various flight states
    uint8 private constant FLIGHT_SCHEDULED = 0;
    uint8 private constant FLIGHT_ON_TIME = 1;
    uint8 private constant FLIGHT_DELAYED = 2;
    uint8 private constant FLIGHT_BOARDING = 3;
    uint8 private constant FLIGHT_IN_AIR = 4;
    uint8 private constant FLIGHT_LANDED = 5;
    uint8 private constant FLIGHT_CANCELLED = 6;
    uint8 private constant FLIGHT_DOES_NOT_EXIST = 7;
    // TicketStatus - enumerates various ticket states
    uint8 private constant TICKET_VOID = 0;
    uint8 private constant TICKET_RESERVED = 1;
    uint8 private constant TICKET_CONFIRMED = 2;
    uint8 private constant TICKET_CLOSED = 3;
    uint8 private constant TICKET_CANCELLATION_IN_PROGRESS = 4;
    uint8 private constant TICKET_CANCELLED = 5;
    uint8 private constant TICKET_DOES_NOT_EXIST = 6;
    // PaymentStatus - enumerates the payment states
    uint8 private constant PAYMENT_PENDING = 0;
    uint8 private constant PAYMENT_COLLECTED = 1;
    uint8 private constant PAYMENT_REFUNDED = 2; // Settled by full refund to customer
    uint8 private constant PAYMENT_SPLIT = 3; // Settled by part refund to customer + part payment to airline
    uint8 private constant PAYMENT_PAID = 4; // Settled by full payment to airline
    //
    address private _ticketContract; // this, contract address
    uint private _ticketNumber; // "1234567890123" unique 13-digit number    
    address private _eagleAirContract; // parent EagleAirline contract address
    //address private _tokenARMS; // tokenARMS address
    EagleAirline private _eagleAirline; // parent EagleAirline object (_eagleAirContract)
    address payable private _operatorAddress; // parent, EagleAirline Operator (Domestice, International) address
    address payable private _buyerAddress; // buyer who bought this ticket - customer address
    uint8 private _ticketStatus; // last known status of ticket
    uint8 private _paymentStatus; // last known status of payment
    uint private _ticketTimeStamp; // time when this was created
    uint private _ticketStatusTimeStamp; // last ticket status update date time
    uint private _paymentStatusTimeStamp; // last payment status update date time
    bool private _refundClaimed;
    // additional TicketInfo
    struct TicketInfo {
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
    }
    TicketInfo private _ticketInfo;
    //


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    constructor (
        //address tokenARMS,
        address eagleAir,
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
        _eagleAirContract = address(eagleAir); // Only the parent can create this contract
        _eagleAirline = EagleAirline(_eagleAirContract);
        _operatorAddress = payable(operatorAddress);
        _buyerAddress = payable(buyerAddress);
        _ticketNumber = ticketNumber;
        // additional info
        _ticketStatus = TICKET_RESERVED;
        _paymentStatus = PAYMENT_PENDING;
        _ticketTimeStamp = block.timestamp;
        _refundClaimed = false;
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
    event TicketReserved (uint flightNumber, uint ticketNumber, uint transferredAmount, string message);
    event TicketUpdate(uint ticketNumber, string message);
    event TicketCancelled(uint ticketNumber, string message);
    event TicketRefundClaimed(uint ticketNumber, string message);
    event ViewTicket(uint ticketNumber, uint flightNumber, string seatNumber, string ticketStatus, string paymentStatus);
    //event TicketCancelled (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, string message);
    event ErrorMessage(string errorMessage);
    event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    modifier OnlyOperator() {
        require(msg.sender == address(_operatorAddress), "Only Airline Flight Operator allowed");
        _;
    }
    //
    modifier OnlyBuyer() {
         require(msg.sender == address(_buyerAddress), "Only Ticket Buyer allowed");
        _;
    }
    //
    modifier OnlyBuyerOrOpertor() {
        require(
                (
                    msg.sender == address(_operatorAddress)
                    || msg.sender == address(_buyerAddress)
                ),
                "Only Airline Flight Operator / Ticket Buyer allowed"
            );
        _;
    }
    /*
    modifier CheckTicketNumber(uint ticketNumber) {
        // Valid ticket numbers are 13 digits
        require(ticketNumber > 1000000000000 && ticketNumber < 10000000000000, "Invalid Ticket Number provided");
        _;
    }
    */
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
        console.log(msg.value, ticketPrice);
        require(msg.value > ticketPrice, "Insufficient Amount provided to complete purchase");
        // Confirm with Airline
        success = _eagleAirline.confirmTicket(_ticketContract, msg.sender);
        require(success, "ERR: Ticket purchase failed");
        // Transfer funds, if any back to customer (sender)
        uint256 transferAmount = (msg.value - ticketPrice);
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
    function selectSeat (string memory seatNumber) OnlyBuyer public returns (bool) {
        return _eagleAirline.selectSeat(_ticketContract, seatNumber);
    }
    
    function _getPercentRefund(uint delayTime, bool isDelayClaim) private pure returns (uint8) {
        if (delayTime >= 24 hours)
            return (isDelayClaim) ? 100 : 100;
        else if (delayTime >= 10 hours && delayTime < 24 hours)
            return (isDelayClaim) ? 40 : 80;
        else if (delayTime >= 2 hours && delayTime < 10 hours)
            return (isDelayClaim) ? 10 : 40;
        else
            return 0;
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
        uint currTime = block.timestamp;
        if (_ticketStatus == TICKET_RESERVED) {
            (success, message) = _eagleAirline.voidTicket(_ticketContract);
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = currTime;
            emit TicketCancelled(_ticketNumber, message);
            //selfdestruct(_buyerAddress);
        } else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS) {
            revert ("Err: Prev CANCELLATION IN PROGRESS");
        } else if (_ticketStatus == TICKET_CANCELLED) {
            revert ("Err: Ticket already CANCELLED");
        }
        if (!_refundClaimed) {
            uint8 flightStatus = _eagleAirline.getflightSts(_ticketInfo.flightNumber);
            require(
                flightStatus >= FLIGHT_SCHEDULED && flightStatus <= FLIGHT_DELAYED,
                "ERR: Ticket cannot be cancelled. Check Flight status"
            );
            uint secondDiff = (_ticketInfo.schDepartureTimeStamp > currTime) ? _ticketInfo.schDepartureTimeStamp - currTime : 0;
            // If < 2 hour	NOT ALLOWED (revert transaction)
            require(secondDiff >= 2 hours, "ERR: Ticket cancellation window closed");
            _ticketStatus = TICKET_CANCELLATION_IN_PROGRESS;
            _ticketStatusTimeStamp = currTime;
            // Calculate refund
            uint8 percentRefund = _getPercentRefund(secondDiff, false);
            require(percentRefund > 0, "ERR: Ticket cancellation window closed. Try claiming a refund.");
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
            _paymentStatusTimeStamp = currTime;
            if (refundAmount > 0 && penaltyAmount > 0) {
                _paymentStatus = PAYMENT_SPLIT;
            } else if (refundAmount > 0 && penaltyAmount == 0) {
                _paymentStatus = PAYMENT_REFUNDED;
            } else if (refundAmount == 0 && penaltyAmount > 0) {
                _paymentStatus = PAYMENT_PAID;
            }
            _ticketInfo.refundAmount = refundAmount;
            _ticketInfo.paidAmount = penaltyAmount;
        }
        //
        _ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = currTime;
        _ticketInfo.seatNumber = "NA";
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
        uint currTime = block.timestamp;
        require(_ticketStatus >= TICKET_RESERVED && _ticketStatus <= TICKET_CONFIRMED, "ERR: Cannot close due to Ticket status (VOID/CLOSED/CANCELLED)");
        require(flightStatus == FLIGHT_LANDED || flightStatus == FLIGHT_CANCELLED, "ERR: Invalid Flight status");
        if (_ticketStatus == TICKET_RESERVED) {
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = currTime;
            emit TicketCancelled(_ticketNumber, message);
        }
        //
        if (!_refundClaimed && _paymentStatus == PAYMENT_COLLECTED) {
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
            // Update payment info
            _paymentStatusTimeStamp = currTime;
            if (refundAmount > 0 && payAmount > 0)
                _paymentStatus = PAYMENT_SPLIT;
            else if (refundAmount > 0 && payAmount == 0)
                _paymentStatus = PAYMENT_REFUNDED;
            else if (refundAmount == 0 && payAmount > 0)
                _paymentStatus = PAYMENT_PAID;
            _ticketInfo.refundAmount = refundAmount;
            _ticketInfo.paidAmount = payAmount;
        }
        //
        _ticketStatus = TICKET_CLOSED;
        _ticketStatusTimeStamp = currTime;
        _ticketInfo.seatNumber = "NA";
        success = true;
        message = string.concat("INFO: Ticket Cancelled. Ticket # ", EagleLib.uintToString(_ticketNumber));
        emit TicketCancelled (_ticketNumber, message);
    }

    // !! PAYABLE !!
    function claimRefund () OnlyBuyer public payable returns (bool success, string memory message) {
        /*
        * Delayed by Airline – Penalty Rules
        * Rule: 
        * If Ticket Status != CLOSED/CANCELLED
        * Customer can claim a refund only once
        * Determine Delay Time
        *   If Flight Status < CANCELLED
        *       Delay Time = 24 Hours i.e. 100% refund
        *   If Flight Status < IN_AIR 
        *       && (Current Time - Scheduled Departure Datetime) >= 24 hours
        *       && (Current Time - NEW Departure Datetime) >= 24 hours
        *       then Delay Time = (Current Time - Scheduled Departure Datetime) - 24 hours
        *       (If Actual Departure Datetime is not updated within 24 hours from Scheduled Departure Datetime	100%
        *   OR if Flight Status = LANDED && (Actual Arrival Datetime - Scheduled Arrival Datetime) > 0
        *       then Delay Time = (Actual Arrival Datetime - Scheduled Arrival Datetime)
        * Based on Delay Time
        *   If >= 2 hours and < 10 hours	10%
        *   If >= 10 hours and < 24 hours	40%
        *   If >= 24 hours	100%
        */
        require(_refundClaimed, "ERR: Refund claim already processed");
        // Check ticket status
        if (_ticketStatus <= TICKET_CLOSED) 
            revert ("ERR: Ticket not elligible");
        else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS)
            revert ("ERR: Ticket CANCELLATION is in progress");
        //
        require(_paymentStatus == PAYMENT_COLLECTED, "ERR: Refund not applicable"); // payment was never collected or has already be refunded/paid
        //
        (uint8 flightStatus, uint schDeparturetTS, , uint newDeparturetTS, uint newArrivalTS) = _eagleAirline.getflightStsTime(_ticketInfo.flightNumber);
        uint256 refundAmount = 0; 
        uint256 penaltyAmount = 0;
        uint currTime = block.timestamp;
        uint delayTime = 0;
        // Caculate Penalty
        if (flightStatus == FLIGHT_CANCELLED) {
            delayTime = 24 hours;
        } else if (
            flightStatus < FLIGHT_IN_AIR 
            && (currTime - schDeparturetTS) > 24 hours
            && (currTime - newDeparturetTS) > 24 hours
        ) {
            delayTime = (currTime - schDeparturetTS) - 24 hours;
        } else if (flightStatus == FLIGHT_LANDED) {
            delayTime = newArrivalTS - schDeparturetTS;
        }
        // Calculate Refund percent on Delay Time
        uint8 percentRefund = _getPercentRefund(delayTime, true);
        require(percentRefund > 0, "ERR: Claim is not valid");
        // Calculate amount based on percent and if any refunds were previously paid
        refundAmount = _ticketInfo.collectedAmount * (percentRefund / 100);
        penaltyAmount = _ticketInfo.collectedAmount - refundAmount; // balance
        bool refundCallSuccess; bool payCallSuccess;
        //if (ARMSToken(_tokenARMS).balanceOf(address(this)) > _ticketInfo.collectedAmount) {  
        if (address(this).balance > _ticketInfo.collectedAmount) {     
            // Refund the Buyer
            if (refundAmount > 0) {
                //refundCallSuccess = ARMSToken(_tokenARMS).transfer(payable(_buyerAddress), refundAmount);
                (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                require(refundCallSuccess, "ERR: Refund claim failed. Contact customer support.");
            }
            // Send balance to Airline
            if (penaltyAmount > 0) {
                //payCallSuccess = ARMSToken(_tokenARMS).transfer(payable(_operatorAddress), penaltyAmount);
                (payCallSuccess, ) = payable(_operatorAddress).call{value: penaltyAmount}("");
                require(payCallSuccess, "ERR: Refund claim failed. Contact customer support.");
            }
        } else {
            message = "ERR: Insufficient funds. Contact customer support.";
            revert (message);
        }
        require(refundCallSuccess || payCallSuccess, "ERR: Refund claim failed. Contact customer support.");
        // Update payment info
        _refundClaimed = true;
        _paymentStatusTimeStamp = currTime;
        if (refundAmount > 0 && penaltyAmount > 0)
            _paymentStatus = PAYMENT_SPLIT;
        else if (refundAmount > 0 && penaltyAmount == 0)
            _paymentStatus = PAYMENT_REFUNDED;
        else if (refundAmount == 0 && penaltyAmount > 0)
            _paymentStatus = PAYMENT_PAID;
        //
        _ticketInfo.refundAmount = refundAmount;
        _ticketInfo.paidAmount = penaltyAmount;
        //
        //_ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatusTimeStamp = _ticketStatusTimeStamp;
        success = true;
        message = string.concat("INFO: Ticket Refund Claimed. Ticket # ", EagleLib.uintToString(_ticketNumber));
        //emit TicketRefundClaimed(_ticketNumber, message);
    }
}