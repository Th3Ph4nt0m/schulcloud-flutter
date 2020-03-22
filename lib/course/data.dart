import 'dart:ui';

import 'package:hive/hive.dart';
import 'package:dartx/dartx.dart';
import 'package:meta/meta.dart';
import 'package:schulcloud/app/app.dart';
import 'package:schulcloud/file/file.dart';

part 'data.g.dart';

@HiveType(typeId: TypeId.course)
class Course implements Entity<Course> {
  Course({
    @required this.id,
    @required this.name,
    this.description,
    @required this.teacherIds,
    @required this.color,
  })  : assert(id != null),
        assert(name != null),
        assert(description?.isBlank != true),
        assert(teacherIds != null),
        assert(color != null),
        lessons = LazyIds<Lesson>(
          collectionId: 'lessons of course $id',
          fetcher: () async => Lesson.fetchList(courseId: id),
        ),
        visibleLessons = LazyIds<Lesson>(
          collectionId: 'visible lessons of course $id',
          fetcher: () async => Lesson.fetchList(courseId: id, hidden: false),
        ),
        files = LazyIds<File>(
          collectionId: 'files of $id',
          fetcher: () => File.fetchList(id),
        );

  Course.fromJson(Map<String, dynamic> data)
      : this(
          id: Id<Course>(data['_id']),
          name: data['name'],
          description: (data['description'] as String).blankToNull,
          teacherIds: (data['teacherIds'] as List<dynamic>).castIds<User>(),
          color: (data['color'] as String).hexToColor,
        );

  static Future<Course> fetch(Id<Course> id) async =>
      Course.fromJson(await services.api.get('courses/$id').json);

  @override
  @HiveField(0)
  final Id<Course> id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<Id<User>> teacherIds;

  @HiveField(4)
  final Color color;

  final LazyIds<Lesson> lessons;
  final LazyIds<Lesson> visibleLessons;

  final LazyIds<File> files;
}

extension CourseId on Id<Course> {
  String get webUrl => scWebUrl('courses/$this');
}

@HiveType(typeId: TypeId.lesson)
class Lesson implements Entity<Lesson>, Comparable<Lesson> {
  const Lesson({
    @required this.id,
    @required this.courseId,
    @required this.name,
    @required this.contents,
    @required this.isHidden,
    @required this.position,
  })  : assert(id != null),
        assert(courseId != null),
        assert(name != null),
        assert(contents != null),
        assert(isHidden != null),
        assert(position != null);

  Lesson.fromJson(Map<String, dynamic> data)
      : this(
          id: Id<Lesson>(data['_id']),
          courseId: Id<Course>(data['courseId']),
          name: data['name'],
          contents: (data['contents'] as List<dynamic>)
              .map((content) => Content.fromJson(content))
              .whereNotNull()
              .toList(),
          isHidden: data['hidden'] ?? false,
          position: data['position'],
        );

  static Future<Lesson> fetch(Id<Lesson> id) async =>
      Lesson.fromJson(await services.api.get('lessons/$id').json);

  static Future<List<Lesson>> fetchList({
    Id<Course> courseId,
    bool hidden,
  }) async {
    final jsonList = await services.api.get('lessons', parameters: {
      if (courseId != null) 'courseId': courseId.value,
      if (hidden == true)
        'hidden': 'true'
      else if (hidden == false)
        'hidden[\$ne]': 'true',
    }).parseJsonList();
    return jsonList.map((data) => Lesson.fromJson(data)).toList();
  }

  @override
  @HiveField(0)
  final Id<Lesson> id;

  @HiveField(3)
  final Id<Course> courseId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<Content> contents;
  Iterable<Content> get visibleContents => contents.where((c) => c.isVisible);

  @HiveField(5)
  final bool isHidden;
  bool get isVisible => !isHidden;

  @HiveField(4)
  final int position;
  @override
  int compareTo(Lesson other) => position.compareTo(other.position);

  String get webUrl => '${courseId.webUrl}/topics/$id';
}

@HiveType(typeId: TypeId.content)
class Content implements Entity<Content> {
  const Content({
    @required this.id,
    @required this.title,
    @required this.isHidden,
    @required this.component,
  })  : assert(id != null),
        assert(title != ''),
        assert(isHidden != null),
        assert(component != null);

  factory Content.fromJson(Map<String, dynamic> data) {
    return Content(
      id: Id(data['_id']),
      title: data['title'] == '' ? null : data['title'],
      isHidden: data['hidden'] ?? false,
      component: Component.fromJson(data),
    );
  }

  // Used before: 2 – 4

  @override
  @HiveField(0)
  final Id<Content> id;

  @HiveField(1)
  final String title;

  @HiveField(5)
  final bool isHidden;
  bool get isVisible => !isHidden;

  @HiveField(6)
  final Component component;
}

abstract class Component {
  const Component();

  factory Component.fromJson(Map<String, dynamic> data) {
    final content = data['content'] ?? {};
    if (data['component'] == 'text') {
      return TextComponent.fromJson(content);
    }
    if (data['component'] == 'Etherpad') {
      return EtherpadComponent.fromJson(content);
    }
    return UnsupportedComponent();
  }
}

@HiveType(typeId: TypeId.unsupportedComponent)
class UnsupportedComponent extends Component {
  const UnsupportedComponent();
}

@HiveType(typeId: TypeId.textComponent)
class TextComponent extends Component {
  const TextComponent({
    @required this.text,
  }) : assert(text != '');

  factory TextComponent.fromJson(Map<String, dynamic> data) {
    return TextComponent(
      text: data['text'] == '' ? null : data['text'],
    );
  }

  @HiveField(0)
  final String text;
}

@HiveType(typeId: TypeId.etherpadComponent)
class EtherpadComponent extends Component {
  const EtherpadComponent({
    @required this.url,
    this.description,
  }) : assert(url != null);

  factory EtherpadComponent.fromJson(Map<String, dynamic> data) {
    return EtherpadComponent(
      url: data['url'],
      description: data['description'] == '' ? null : data['description'],
    );
  }

  @HiveField(0)
  final String url;

  @HiveField(1)
  final String description;
}
