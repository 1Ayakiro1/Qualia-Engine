import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// The desktop's icon vocabulary. Keep package-specific choices here so
/// screens use the same Regular/Fill states and meaning without depending on the pack.
/// Fonts are bundled with the app; rendering never requires network access.
@staticIconProvider
abstract final class AppIcons {
  static const add = PhosphorIconsRegular.plus;
  static const arrowBack = PhosphorIconsRegular.arrowLeft;
  static const arrowDownRight = PhosphorIconsRegular.arrowDownRight;
  static const arrowUpRight = PhosphorIconsRegular.arrowUpRight;
  static const bell = PhosphorIconsRegular.bell;
  static const bellRinging = PhosphorIconsRegular.bellRinging;
  static const bolt = PhosphorIconsRegular.lightning;
  static const brain = PhosphorIconsRegular.brain;
  static const branch = PhosphorIconsRegular.gitBranch;
  static const bug = PhosphorIconsRegular.bug;
  static const caretDown = PhosphorIconsRegular.caretDown;
  static const caretLeft = PhosphorIconsRegular.caretLeft;
  static const caretRight = PhosphorIconsRegular.caretRight;
  static const caretUp = PhosphorIconsRegular.caretUp;
  static const caretsLeft = PhosphorIconsRegular.caretDoubleLeft;
  static const caretsRight = PhosphorIconsRegular.caretDoubleRight;
  static const caretsUpDown = PhosphorIconsRegular.caretUpDown;
  static const chart = PhosphorIconsRegular.chartLine;
  static const check = PhosphorIconsRegular.check;
  static const checkCircle = PhosphorIconsRegular.checkCircle;
  static const circle = PhosphorIconsRegular.circle;
  static const circleFilled = PhosphorIconsFill.circle;
  static const close = PhosphorIconsRegular.x;
  static const cloudOffline = PhosphorIconsRegular.cloudSlash;
  static const code = PhosphorIconsRegular.code;
  static const copy = PhosphorIconsRegular.copy;
  static const cpu = PhosphorIconsRegular.cpu;
  static const cursor = PhosphorIconsRegular.cursor;
  static const database = PhosphorIconsRegular.database;
  static const download = PhosphorIconsRegular.downloadSimple;
  static const downloaded = PhosphorIconsRegular.checkCircle;
  static const dragHandle = PhosphorIconsRegular.dotsSixVertical;
  static const eraser = PhosphorIconsRegular.eraser;
  static const palette = PhosphorIconsRegular.palette;
  static const error = PhosphorIconsRegular.warningCircle;
  static const expand = PhosphorIconsRegular.arrowsOut;
  static const externalLink = PhosphorIconsRegular.arrowSquareOut;
  static const eye = PhosphorIconsRegular.eye;
  static const eyeOff = PhosphorIconsRegular.eyeSlash;
  static const fileOpen = PhosphorIconsRegular.fileArrowUp;
  static const fitCanvas = PhosphorIconsRegular.cornersOut;
  static const flag = PhosphorIconsRegular.flag;
  static const folderOpen = PhosphorIconsRegular.folderOpen;
  static const folders = PhosphorIconsRegular.folders;
  static const globe = PhosphorIconsRegular.globe;
  static const grid = PhosphorIconsRegular.squaresFour;
  static const gridEdit = PhosphorIconsRegular.gridFour;
  static const heart = PhosphorIconsRegular.heart;
  static const heartFilled = PhosphorIconsFill.heart;
  static const heartbeat = PhosphorIconsRegular.heartbeat;
  static const history = PhosphorIconsRegular.clockCounterClockwise;
  static const hourglass = PhosphorIconsRegular.hourglass;
  static const info = PhosphorIconsRegular.info;
  static const layers = PhosphorIconsRegular.stack;
  static const linkOff = PhosphorIconsRegular.linkBreak;
  static const logout = PhosphorIconsRegular.signOut;
  static const magnet = PhosphorIconsRegular.magnetStraight;
  static const microphone = PhosphorIconsRegular.microphone;
  static const minus = PhosphorIconsRegular.minus;
  static const moon = PhosphorIconsRegular.moon;
  static const more = PhosphorIconsRegular.dotsThree;
  static const mountains = PhosphorIconsRegular.mountains;
  static const network = PhosphorIconsRegular.graph;
  static const note = PhosphorIconsRegular.note;
  static const package = PhosphorIconsRegular.package;
  static const pause = PhosphorIconsRegular.pause;
  static const pencil = PhosphorIconsRegular.pencilSimple;
  static const play = PhosphorIconsRegular.play;
  static const plugOff = PhosphorIconsRegular.plugs;
  static const puzzle = PhosphorIconsRegular.puzzlePiece;
  static const record = PhosphorIconsRegular.record;
  static const refresh = PhosphorIconsRegular.arrowClockwise;
  static const reset = PhosphorIconsRegular.arrowCounterClockwise;
  static const save = PhosphorIconsRegular.floppyDisk;
  static const scissors = PhosphorIconsRegular.scissors;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const settings = PhosphorIconsRegular.gearSix;
  static const shieldCheck = PhosphorIconsRegular.shieldCheck;
  static const shrink = PhosphorIconsRegular.arrowsIn;
  static const sidebar = PhosphorIconsRegular.sidebarSimple;
  static const sidebarFilled = PhosphorIconsFill.sidebarSimple;
  static const signal = PhosphorIconsRegular.broadcast;
  static const sliders = PhosphorIconsRegular.slidersHorizontal;
  static const sparkles = PhosphorIconsRegular.sparkle;
  static const square = PhosphorIconsRegular.square;
  static const stop = PhosphorIconsRegular.stop;
  static const store = PhosphorIconsRegular.storefront;
  static const sun = PhosphorIconsRegular.sun;
  static const terminal = PhosphorIconsRegular.terminalWindow;
  static const timer = PhosphorIconsRegular.timer;
  static const toBottom = PhosphorIconsRegular.arrowLineDown;
  static const toTop = PhosphorIconsRegular.arrowLineUp;
  static const trash = PhosphorIconsRegular.trash;
  static const usb = PhosphorIconsRegular.usb;
  static const user = PhosphorIconsRegular.user;
  static const userCircle = PhosphorIconsRegular.userCircle;
  static const users = PhosphorIconsRegular.users;
  static const warning = PhosphorIconsRegular.warning;
  static const waveform = PhosphorIconsRegular.waveform;
  static const workflow = PhosphorIconsRegular.treeStructure;
  static const zoomIn = PhosphorIconsRegular.magnifyingGlassPlus;
  static const zoomOut = PhosphorIconsRegular.magnifyingGlassMinus;

  /// Resolve selected states centrally; unknown/author-provided icons are kept.
  static IconData resolve(IconData icon, {required bool active}) =>
      active ? (_filled[icon] ?? icon) : icon;

  static final Map<IconData, IconData> _filled = {
    add: PhosphorIconsFill.plus,
    arrowBack: PhosphorIconsFill.arrowLeft,
    arrowDownRight: PhosphorIconsFill.arrowDownRight,
    arrowUpRight: PhosphorIconsFill.arrowUpRight,
    bell: PhosphorIconsFill.bell,
    bellRinging: PhosphorIconsFill.bellRinging,
    bolt: PhosphorIconsFill.lightning,
    brain: PhosphorIconsFill.brain,
    branch: PhosphorIconsFill.gitBranch,
    bug: PhosphorIconsFill.bug,
    caretDown: PhosphorIconsFill.caretDown,
    caretLeft: PhosphorIconsFill.caretLeft,
    caretRight: PhosphorIconsFill.caretRight,
    caretUp: PhosphorIconsFill.caretUp,
    caretsLeft: PhosphorIconsFill.caretDoubleLeft,
    caretsRight: PhosphorIconsFill.caretDoubleRight,
    caretsUpDown: PhosphorIconsFill.caretUpDown,
    chart: PhosphorIconsFill.chartLine,
    check: PhosphorIconsFill.check,
    checkCircle: PhosphorIconsFill.checkCircle,
    circle: PhosphorIconsFill.circle,
    close: PhosphorIconsFill.x,
    cloudOffline: PhosphorIconsFill.cloudSlash,
    code: PhosphorIconsFill.code,
    copy: PhosphorIconsFill.copy,
    cpu: PhosphorIconsFill.cpu,
    cursor: PhosphorIconsFill.cursor,
    database: PhosphorIconsFill.database,
    download: PhosphorIconsFill.downloadSimple,
    dragHandle: PhosphorIconsFill.dotsSixVertical,
    eraser: PhosphorIconsFill.eraser,
    palette: PhosphorIconsFill.palette,
    error: PhosphorIconsFill.warningCircle,
    expand: PhosphorIconsFill.arrowsOut,
    externalLink: PhosphorIconsFill.arrowSquareOut,
    eye: PhosphorIconsFill.eye,
    eyeOff: PhosphorIconsFill.eyeSlash,
    fileOpen: PhosphorIconsFill.fileArrowUp,
    fitCanvas: PhosphorIconsFill.cornersOut,
    flag: PhosphorIconsFill.flag,
    folderOpen: PhosphorIconsFill.folderOpen,
    folders: PhosphorIconsFill.folders,
    globe: PhosphorIconsFill.globe,
    grid: PhosphorIconsFill.squaresFour,
    gridEdit: PhosphorIconsFill.gridFour,
    heart: PhosphorIconsFill.heart,
    heartbeat: PhosphorIconsFill.heartbeat,
    history: PhosphorIconsFill.clockCounterClockwise,
    hourglass: PhosphorIconsFill.hourglass,
    info: PhosphorIconsFill.info,
    layers: PhosphorIconsFill.stack,
    linkOff: PhosphorIconsFill.linkBreak,
    logout: PhosphorIconsFill.signOut,
    magnet: PhosphorIconsFill.magnetStraight,
    microphone: PhosphorIconsFill.microphone,
    minus: PhosphorIconsFill.minus,
    moon: PhosphorIconsFill.moon,
    more: PhosphorIconsFill.dotsThree,
    mountains: PhosphorIconsFill.mountains,
    network: PhosphorIconsFill.graph,
    note: PhosphorIconsFill.note,
    package: PhosphorIconsFill.package,
    pause: PhosphorIconsFill.pause,
    pencil: PhosphorIconsFill.pencilSimple,
    play: PhosphorIconsFill.play,
    plugOff: PhosphorIconsFill.plugs,
    puzzle: PhosphorIconsFill.puzzlePiece,
    record: PhosphorIconsFill.record,
    refresh: PhosphorIconsFill.arrowClockwise,
    reset: PhosphorIconsFill.arrowCounterClockwise,
    save: PhosphorIconsFill.floppyDisk,
    scissors: PhosphorIconsFill.scissors,
    search: PhosphorIconsFill.magnifyingGlass,
    settings: PhosphorIconsFill.gearSix,
    shieldCheck: PhosphorIconsFill.shieldCheck,
    shrink: PhosphorIconsFill.arrowsIn,
    sidebar: PhosphorIconsFill.sidebarSimple,
    signal: PhosphorIconsFill.broadcast,
    sliders: PhosphorIconsFill.slidersHorizontal,
    sparkles: PhosphorIconsFill.sparkle,
    square: PhosphorIconsFill.square,
    stop: PhosphorIconsFill.stop,
    store: PhosphorIconsFill.storefront,
    sun: PhosphorIconsFill.sun,
    terminal: PhosphorIconsFill.terminalWindow,
    timer: PhosphorIconsFill.timer,
    toBottom: PhosphorIconsFill.arrowLineDown,
    toTop: PhosphorIconsFill.arrowLineUp,
    trash: PhosphorIconsFill.trash,
    usb: PhosphorIconsFill.usb,
    user: PhosphorIconsFill.user,
    userCircle: PhosphorIconsFill.userCircle,
    users: PhosphorIconsFill.users,
    warning: PhosphorIconsFill.warning,
    waveform: PhosphorIconsFill.waveform,
    workflow: PhosphorIconsFill.treeStructure,
    zoomIn: PhosphorIconsFill.magnifyingGlassPlus,
    zoomOut: PhosphorIconsFill.magnifyingGlassMinus,
  };
}
