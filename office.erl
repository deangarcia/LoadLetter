-module(office).
-export([room/4, student/2, officedemo/0]).

room(Students, Capacity, Queue, Helping) -> 
  receive
    {From, help_me} ->
      case Helping of
        true ->
           From ! {self(), busy},
           room(Students, Capacity, Queue, true); % do nothing because they are already in queue
        false ->
           From ! {self(), ok},
           room(Students, Capacity, Queue, Helping) % add to queue here add to end
      end;

    {From, enter, Name} when Capacity > 0 ->
      case length(Queue) of
        % There is capacity and no one is waiting to get in because 
        % the queue is empty so add new student to students
        0 -> 
          From ! {self(), ok},
          room([Name|Students], Capacity - 1, Queue, Helping);
        % There is capacity but there is people waiting in the 
        % queue so check if the person trying to get in is at the front 
        _ -> 
          case string:str(Queue, [Name]) of
              % If person is not on in the queue send them to back 
              0 ->
                From ! {self(), room_full, (length(Queue) + 1) * 1000},
                room(Students, Capacity, Queue ++ [Name], Helping);
              % If person is the first in queue enter room and remove from queue
              1 ->
                From ! {self(), ok},
                room([hd(Queue)|Students], Capacity - 1, lists:delete(Name, Queue), Helping);
              % if person is in queue already then keep them in same spot have them 
              % wait for thousand ms times their line position
              _ ->
                From ! {self(), room_full, string:str(Queue, [Name]) * 1000},
                room(Students, Capacity, Queue, Helping)
          end
      end;

    {From, enter, Name} ->
      case lists:member(Name, Queue) of
        true ->
           From ! {self(), room_full, string:str(Queue, [Name]) * 1000},
           room(Students, Capacity, Queue, Helping); % do nothing because they are already in queue
        false ->
           From ! {self(), room_full, (length(Queue) + 1) * 1000},
           room(Students, Capacity, Queue ++ [Name], Helping) % add to queue here add to end
      end;

    {thanks} when Helping =:= true -> 
    % iffy here if no message is sent back will the rest of student 
    % just continue? 
    %  From ! {self(), leave},
      room(Students, Capacity, Queue, false);

    % student leaving
    {From, leave, Name} ->
      % make sure they are already in the room
      case lists:member(Name, Students) of
        true ->
          From ! {self(), ok},
          room(lists:delete(Name, Students), Capacity + 1, Queue, Helping);
        false ->
          From ! {self(), not_found},
          room(Students, Capacity, Queue, Helping)
      end
  end.

studentWork(Name) ->
  SleepTime = rand:uniform(7000) + 3000,
  io:format("~s entered the Office and will work for ~B ms.~n", [Name, SleepTime]),
  timer:sleep(SleepTime).

student(Office, Name) ->
% every student will be in the office for a random sleep ms from
% 0 to 3000
  timer:sleep(rand:uniform(3000)),
  Office ! {self(), enter, Name},
  receive
    % Success; can enter room.
    {_, ok} ->
      studentWork(Name),
      Office ! {self(), help_me},
      io:format("~s is receiving help.~n", [Name]),
      Office ! {thanks},
      SleepTime = rand:uniform(5000) + 5000,
      timer:sleep(SleepTime),
      io:format("~s left the Office.~n", [Name]),
      Office ! {self(), leave, Name};

    {_, busy} ->
      timer:sleep(1000),
      io:format("~s wanted help but the instructor was busy.~n", [Name]),
      Office ! {self(), help_me};

    {_, room_full, SleepTime} ->
      io:format("~s could not enter and must wait ~B ms.~n", [Name, SleepTime]),
      timer:sleep(SleepTime),
      student(Office, Name)
  end.

officedemo() ->
% create a room called office and calls the room function passing in an empty list for Students
% capacity at 3 and an empty list for Queue
  R = spawn(office, room, [[], 3, [], false]), % start the room process with an empty list of students

  % creats a new student thread and passes in two parameters a room and a student name
  spawn(office, student, [R, "Ada"]),
  spawn(office, student, [R, "Barbara"]),
  spawn(office, student, [R, "Charlie"]),
  spawn(office, student, [R, "Donald"]),
  spawn(office, student, [R, "Elaine"]),
  spawn(office, student, [R, "Frank"]),
  spawn(office, student, [R, "George"]).