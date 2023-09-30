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
/*
EPOCH refers to various timestamp representation, but usually it is known as UNIX timestamp.
It is a 32-bit integer value starting from 0, which represents 1970-01-01T00:00:00Z.
For example, 2018-09-10T12:34:56+11:00 is the epoch value of 1536543296.
Epoch time cannot represent any date before 1970 and won't be able to represent after January 19th, 2038 because epoch uses 32-bit integer value.
*/
/*
* EagleLib:
*   For handling of strings, dates and other common functions/operations
*/
library EagleLib {
    // enum
    enum DatePart { YEAR, MONTH, DAY, HOUR, MINUTES, SECONDS }
    // As we will be deploying our library in 2023 (or later)
    uint16 constant BASEYEAR = 1970;
    //uint16 constant YEAR2019 = 2019;
    uint16 constant LEAPYEAR2020 = 2020;
    uint constant BODJAN012020 = 1577836800; // 2019/12/31 23:59:59
    // DAYS in a year
    uint constant DAYS_IN_YEAR = 365;
    uint constant DAYS_IN_LEAP_YEAR = 366;
    // Seconds
    uint constant SECONDS_PER_MINUTE = 60;
    uint constant SECONDS_PER_HOUR = SECONDS_PER_MINUTE * 60;
    uint constant SECONDS_PER_DAY = SECONDS_PER_HOUR * 24;
    uint constant SECONDS_PER_YEAR = SECONDS_PER_DAY * DAYS_IN_YEAR;
    uint constant SECONDS_PER_LEAP_YEAR = SECONDS_PER_DAY * DAYS_IN_LEAP_YEAR;
    //
    /*
    struct DateTime {
        uint16 dt_year;
        uint8 dt_month;
        uint8 dt_day;
        uint8 dt_hour; // H24
        uint8 dt_minutes;
        uint8 dt_seconds;
    }
    */
    //
    struct Date {
        uint16 dt_year;
        uint8 dt_month;
        uint8 dt_day;
    }
    //
    function stringLength(string memory s) public pure returns (uint256) {
        return bytes(s).length;
    }
    //
    function stringCompare(string memory s1, string memory s2) public pure returns (bool) {
        return (
            keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2))
        );
    }
    //
    function uintToString (uint nValue) internal pure returns (string memory strValue) {
        if (nValue == 0) {
            return "0"; // straight forward
        }
        uint nTemp = nValue;
        uint nDigits;
        // Loop and determine # of digits
        while (nTemp != 0) {
            nDigits++;
            nTemp /= 10;
        }
        // create a buffer of nDigits
        bytes memory bStr = new bytes(nDigits);
        // Loop and assign each digit to the buffer
        while (nValue != 0) {
            nDigits--;
            bStr[nDigits] = bytes1(uint8(48 + (nValue % 10)));
            nValue /= 10;
        }
        return string(bStr);
    }
    //
    function isLeapYear (uint16 year) internal pure returns (bool) {
        require(year > BASEYEAR && year < 2038, "!ERROR! isLeapYear: Invalid year.");
        if (year % 4 == 0 && year % 100 != 0) {
            return true;
        }
        else if (year % 400 == 0) {
            return true;
        }
        return false;
    }
    //
    function getTSTimeDiff (uint startDate, uint endDate, DatePart datePart) internal pure returns (uint timeDiff) {
        require(startDate <= endDate, "!ERROR! getDateDiff - startDate > endDate");
        if (datePart == DatePart.MINUTES)  {
            timeDiff = (endDate - startDate) / SECONDS_PER_MINUTE;
        } else if (datePart == DatePart.HOUR) {
            timeDiff = (endDate - startDate) / SECONDS_PER_HOUR;
         } else if (datePart == DatePart.DAY) {
            timeDiff = (endDate - startDate) / SECONDS_PER_DAY;
        }  else { // assume seconds
            timeDiff = (endDate - startDate);
        }
    }
    //
    function addTimeToTS (uint sourceTS, DatePart datePart, uint timeToAdd) internal pure returns (uint resultTS) {
        if (datePart == DatePart.MINUTES)  {
            resultTS = sourceTS + (timeToAdd * SECONDS_PER_MINUTE);
        } else if (datePart == DatePart.HOUR) {
           resultTS = sourceTS + (timeToAdd * SECONDS_PER_HOUR);
         } else if (datePart == DatePart.DAY) {
            resultTS = sourceTS + (timeToAdd * SECONDS_PER_DAY);
        }  else { // assume seconds
           resultTS = sourceTS + timeToAdd;
        }
    }
    //
    function substractTimeFromTS (uint sourceTS, DatePart datePart, uint timeToSubstractAdd) internal pure returns (uint resultTS) {
        if (datePart == DatePart.MINUTES)  {
            resultTS = sourceTS - (timeToSubstractAdd * SECONDS_PER_MINUTE);
        } else if (datePart == DatePart.HOUR) {
           resultTS = sourceTS - (timeToSubstractAdd * SECONDS_PER_HOUR);
         } else if (datePart == DatePart.DAY) {
            resultTS = sourceTS - (timeToSubstractAdd * SECONDS_PER_DAY);
        }  else { // assume seconds
           resultTS = sourceTS - timeToSubstractAdd;
        }
    }
    //
    function leapYearsBefore(uint year) private pure returns (uint) {
        year -= 1; // go back a year
        return year / 4 - year / 100 + year / 400;
    }
    // Get days in a month
    function getDaysInMonth(uint8 month, uint16 year) private pure returns (uint8) {
        // Months with 31 days
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        } else if (month == 2) { // Feb
            return (isLeapYear(year)) ? 29 : 28;
        }
        else { // default to 30 days
            return 30;
        }
    }
    // EPOCH to string Date
    function convertTimestampToDate(uint timestamp) public pure returns (string memory strDate) {
        Date memory date;
        
        uint secondsAccountedFor = 0;
        uint buf;
        uint8 i;
        //Get  Year
        date.dt_year = getYear(timestamp);
        buf = leapYearsBefore(date.dt_year) - leapYearsBefore(BASEYEAR);
        //
        secondsAccountedFor += SECONDS_PER_LEAP_YEAR * buf;
        secondsAccountedFor += SECONDS_PER_YEAR * (date.dt_year - BASEYEAR - buf);

        // Month
        uint secondsInMonth;
        for (i = 1; i <= 12; i++) {
                secondsInMonth = SECONDS_PER_DAY * getDaysInMonth(i, date.dt_year);
                if (secondsInMonth + secondsAccountedFor > timestamp) {
                        date.dt_month = i;
                        break;
                }
                secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(date.dt_month, date.dt_year); i++) {
                if (SECONDS_PER_DAY + secondsAccountedFor > timestamp) {
                        date.dt_day = i;
                        break;
                }
                secondsAccountedFor += SECONDS_PER_DAY;
        }
        strDate = string(abi.encodePacked(toString(date.dt_day), "-", toString(date.dt_month), "-", toString(date.dt_year)));
    }
    //
    function getYear(uint timestamp) private pure returns (uint16) {
        uint secondsAccountedFor = 0;
        uint16 year;
        uint numLeapYears;

        // Year
        year = uint16(BASEYEAR + timestamp / SECONDS_PER_YEAR);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(BASEYEAR);

        secondsAccountedFor += SECONDS_PER_LEAP_YEAR * numLeapYears;
        secondsAccountedFor += SECONDS_PER_YEAR * (year - BASEYEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
                if (isLeapYear(uint16(year - 1))) {
                        secondsAccountedFor -= SECONDS_PER_LEAP_YEAR;
                }
                else {
                        secondsAccountedFor -= SECONDS_PER_YEAR;
                }
                year -= 1;
        }
        return year;
    }
    
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    
    // Function to compare two strings.
    function compareStrings(string memory value1, string memory value2) public pure returns (bool) {
        return (keccak256(abi.encodePacked(value1)) == keccak256(abi.encodePacked(value2)));
    }
}