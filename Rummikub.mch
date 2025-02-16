MACHINE Rummikub

SETS
  NAME = {NAME1, NAME2, NAME3, NAME4};
  GAME_STATE = {NOT_RUNNING, ADDING_PLAYERS, DRAWING_INITIAL_TILES, START_TURN, MELDING, FINISH_TURN, FINISHED}

CONSTANTS
  VALID_PLAYERS_NUMS, VALID_PLAYERS_IDS,
  TILES, NUM_STARTING_TILES, TILES_PER_SET, SET_PER_COLOR, COLOR, NUMBER, MIN_TILES_PER_GAME

PROPERTIES        
  VALID_PLAYERS_NUMS = 2..4 & 
  VALID_PLAYERS_IDS = 1..4 & 

  /**************************************** TILES **************************************************/
  // Tiles are actually naturals. 
  // Color from tile X can be retrived using: (i//(TILES_PER_SET*SET_PER_COLOR)) (floor division)
  // Number from tile X can be retrived using: (i%TILES_PER_SET) 

  TILES = 0..103 &
  NUM_STARTING_TILES = 14 & 
  TILES_PER_SET = 13 & 
  SET_PER_COLOR = 2 & 
  MIN_TILES_PER_GAME = 3 &

  COLOR : TILES -->> 0..3 & 
  !xx.(xx : TILES => {xx |-> xx /(TILES_PER_SET*SET_PER_COLOR)} <: COLOR) & 

  NUMBER : TILES -->> 0..12 & 
  !xx.(xx : TILES => {xx |-> xx mod TILES_PER_SET} <: NUMBER)

VARIABLES 
  state, 
  players, num_players, player_turn, 
  runs, groups, in_sack, players_racks, 
  backup_runs, backup_groups, backup_rack, in_hand

INVARIANT
  state : GAME_STATE & 

  /**************************************** PLAYERS **************************************************/

  // Number of players: if the game has started, there should be a valid number of players
  (state /= NOT_RUNNING => num_players : VALID_PLAYERS_NUMS) & 

  // Players: a function of names (but parcial injective and indexed by naturals)
  (state /= NOT_RUNNING => players : VALID_PLAYERS_IDS >+> NAME) &

  // Player turn
  (state /= NOT_RUNNING => player_turn <= num_players) &
  player_turn : NATURAL1 &

  /************************************** PLAYERS RACKS AND SACK *************************************/

  in_sack <: TILES &

  players_racks : VALID_PLAYERS_IDS +-> POW(TILES) &
  dom(players_racks) = dom(players) & // 
  
  UNION(xx).(xx : ran(players_racks) \/ runs \/ groups \/ {in_sack, in_hand} | xx) = TILES &

  !xx.(xx: TILES => (card({yy | yy : (ran(players_racks) \/ runs \/ groups \/ {in_sack, in_hand}) & xx : yy}) = 1)) & 


  /********************************** RUNS AND GROUPS ************************************************/

  // A run is 3 or more in a row of the same color
  // Number of unique colors must be equal to 1
  // Number of unique numbers must be equal to run size
  // Diference from minimal to maximal element must be equal to run size
  runs <: POW(TILES) &
  !xx.(xx : runs => ((card(xx) >= MIN_TILES_PER_GAME) & (card(COLOR[xx]) = 1) & (card(NUMBER[xx]) = card(xx)))) &
  !xx.(xx : runs => (max(xx) - min(xx) + 1) = card(xx)) &

  // A group is 3 or more of the same number that are all different colors
  // Number of unique colors must be equal to the group size
  // Number of unique numbers must be equal 1
  groups <: POW(TILES) &
  !xx.(xx : groups => (card(xx) >= MIN_TILES_PER_GAME) & (card(COLOR[xx]) = card(xx)) & (card(NUMBER[xx]) = 1)) &

  in_hand <: TILES &

  /********************************** BACKUPS ************************************************/

  backup_rack <: TILES &
  (state /= MELDING => backup_groups <: groups) &
  (state /= MELDING => backup_runs <: runs)

INITIALISATION 
  state := NOT_RUNNING || 
  players := {} || num_players := 0 || player_turn := 1 ||
  runs := {} || groups := {} || in_sack := TILES || players_racks := {} || 
  backup_groups := {} || backup_runs := {} || backup_rack := {} || in_hand := {}

OPERATIONS

  /********************************** STATE: NOT_RUNNING ************************************************/

  start_game(nn) =
    PRE state = NOT_RUNNING & nn : VALID_PLAYERS_NUMS 
    THEN 
      num_players := nn || 
      state := ADDING_PLAYERS
    END;

  /********************************** STATE: ADDING_PLAYERS **********************************************/

  add_player(xx) = 
    PRE state = ADDING_PLAYERS & xx : NAME & xx /: ran(players) & card(players) < num_players
    THEN 
      IF card(players) + 1 = num_players THEN
        players := players <+ {card(players) + 1 |-> xx} || players_racks := players_racks <+ {card(players) + 1 |-> {}} || 
        state := DRAWING_INITIAL_TILES
      ELSE
        players := players <+ {card(players) + 1 |-> xx} || players_racks := players_racks <+ {card(players) + 1 |-> {}}
      END
    END;

  /********************************** STATE: DRAWING_INITIAL_TILES **********************************************/

  draw_initial_tiles(xx) = 
    PRE state = DRAWING_INITIAL_TILES & xx : ran(players) & players_racks(players~(xx)) = {}
    THEN
      ANY subset_tiles 
      WHERE subset_tiles <: in_sack & card(subset_tiles) = NUM_STARTING_TILES
      THEN 
        IF card(players_racks |> { {} }) = 1 THEN
          players_racks := players_racks <+ {players~(xx) |-> subset_tiles} || in_sack := in_sack - subset_tiles || 
          state := START_TURN
        ELSE
          players_racks := players_racks <+ {players~(xx) |-> subset_tiles} || in_sack := in_sack - subset_tiles
        END
      END
    END;

  /********************************** STATE: PLAYING **********************************************/
     
  next_turn(xx) = 
    PRE state = FINISH_TURN & xx : ran(players) & players~(xx) = player_turn
    THEN
      // first checks if there is a winner
      IF players_racks(players~(xx)) = {} THEN
        state := FINISHED
      // select: if theres a tile in the sack
      // if can make a move
      ELSIF player_turn = num_players THEN
        player_turn := 1 || state := START_TURN
      ELSE
        player_turn := player_turn + 1 || 
        state := START_TURN
      END
    END;

  draw_tile(xx) =
    PRE state = START_TURN & xx : ran(players) & players~(xx) = player_turn
    THEN
      IF card(in_sack) > 0 THEN
        ANY yy
        WHERE yy : in_sack
        THEN 
          in_sack := in_sack - {yy} || players_racks(players~(xx)) := players_racks(players~(xx)) \/ {yy} || 
          state := FINISH_TURN
        END
      ELSE
        state := FINISH_TURN
      END
    END;
 
  start_melding(xx) = 
    PRE state = START_TURN & xx : ran(players) & players~(xx) = player_turn
    THEN
      in_hand := players_racks(players~(xx)) || players_racks(players~(xx)) := {} ||
      backup_groups := groups || backup_runs := runs || backup_rack := players_racks(players~(xx)) ||
      state := MELDING
    END;

  remove_group(xx, gg) = 
    PRE state = MELDING  & xx : ran(players) & players~(xx) = player_turn & gg : groups
    THEN
      groups := groups - {gg} || in_hand := in_hand \/ gg
    END;

  remove_run(xx, rr) = 
    PRE state = MELDING  & xx : ran(players) & players~(xx) = player_turn & rr : runs
    THEN
      runs := runs - {rr} || in_hand := in_hand \/ rr
    END;

  add_group(xx, gg) =
    PRE state = MELDING & xx : ran(players) & players~(xx) = player_turn & gg <: in_hand &
    (card(gg) >= MIN_TILES_PER_GAME) & (card(COLOR[gg]) = card(gg)) & (card(NUMBER[gg]) = 1)
    THEN
      groups := groups \/ {gg} || in_hand := in_hand - gg
    END;

  add_run(xx, rr) =
    PRE state = MELDING & xx : ran(players) & players~(xx) = player_turn & rr <: in_hand & 
    (card(rr) >= MIN_TILES_PER_GAME) & (card(COLOR[rr]) = 1) & (card(NUMBER[rr]) = card(rr)) & (max(rr) - min(rr) + 1) = card(rr)
    THEN
      runs := runs \/ {rr} || in_hand := in_hand - rr
    END;

  finish_melding(xx) = 
    PRE state = MELDING & xx : ran(players) & players~(xx) = player_turn & in_hand <<: backup_rack
    THEN
      state := FINISH_TURN || backup_runs := {} || backup_groups := {} || backup_rack := {} || players_racks(players~(xx)) := in_hand || in_hand := {}
    END;
  
  reset_turn(xx) = 
    PRE state = MELDING & xx : ran(players) & players~(xx) = player_turn
    THEN
      runs := backup_runs || groups := backup_groups || players_racks(players~(xx)) := backup_rack || in_hand := {} ||
      state := START_TURN 
    END;


  // A primeira linha tem que ser um PRE ao invés de IF, mas fica assim pra visualizar o processo
  yy <-- winner =
    IF state = FINISHED THEN 
      yy := {xx | xx : ran(players) & players_racks(players~(xx)) = {} }
    ELSE
      yy := {}
    END;
    
  yy <-- player_score(xx) =
    yy := SIGMA (zz) . (zz : players_racks(players~(xx)) | NUMBER(zz) + 1)

END
